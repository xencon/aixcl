-- Migration: Security-First Agentic Foundation
-- Phase 1: PostgreSQL Schema for Agent Auditing
-- Date: 2026-05-01
-- Issue: #917

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Agent sessions table with full conversation capture
CREATE TABLE IF NOT EXISTS agent_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(64) NOT NULL,
    agent_mode VARCHAR(16) NOT NULL CHECK (agent_mode IN ('primary', 'subagent')),
    parent_session_id UUID REFERENCES agent_sessions(session_id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(16) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'completed', 'failed', 'blocked')),
    human_approval_id UUID,
    conversation_log JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    previous_hash VARCHAR(64),
    current_hash VARCHAR(64) GENERATED ALWAYS AS (
        encode(digest(
            session_id::text || agent_name || started_at::text || 
            COALESCE(conversation_log::text, '[]'),
            'sha256'
        ), 'hex')
    ) STORED
);

COMMENT ON TABLE agent_sessions IS 'Records all agent sessions with full conversation capture for audit trail';

-- Agent actions table for detailed action logging
CREATE TABLE IF NOT EXISTS agent_actions (
    action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES agent_sessions(session_id),
    action_type VARCHAR(64) NOT NULL,
    tool_used VARCHAR(64),
    tool_input JSONB,
    tool_output JSONB,
    execution_time_ms INTEGER,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    security_scan_status VARCHAR(16) 
        CHECK (security_scan_status IN ('pending', 'passed', 'failed')),
    compliance_status VARCHAR(16) 
        CHECK (compliance_status IN ('pending', 'passed', 'failed')),
    previous_hash VARCHAR(64),
    current_hash VARCHAR(64),
    git_commit_hash VARCHAR(40),
    git_branch VARCHAR(255)
);

COMMENT ON TABLE agent_actions IS 'Immutable log of all agent actions with cryptographic chain';

-- Human approvals table for critical actions
CREATE TABLE IF NOT EXISTS human_approvals (
    approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requested_by VARCHAR(64) NOT NULL,
    action_type VARCHAR(64) NOT NULL,
    action_description TEXT,
    justification TEXT NOT NULL,
    files_affected TEXT[],
    risk_score DECIMAL(3,1),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_by VARCHAR(64),
    approved_at TIMESTAMP WITH TIME ZONE,
    approval_status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (approval_status IN ('pending', 'approved', 'rejected', 'expired')),
    escalation_level INTEGER DEFAULT 1 CHECK (escalation_level BETWEEN 1 AND 3),
    escalation_reason TEXT,
    timeout_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '24 hours'
);

COMMENT ON TABLE human_approvals IS 'Tracks human-in-the-loop approvals for critical actions';

-- Audit logs table with 30-day retention
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    severity VARCHAR(16) NOT NULL 
        CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    agent_name VARCHAR(64) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    event_description TEXT,
    details JSONB,
    source_ip INET,
    session_id UUID REFERENCES agent_sessions(session_id),
    previous_hash VARCHAR(64),
    current_hash VARCHAR(64),
    retention_until TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '30 days'
);

COMMENT ON TABLE audit_logs IS 'Immutable audit trail with automatic 30-day retention';

-- Safe patterns table for automation
CREATE TABLE IF NOT EXISTS safe_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pattern_type VARCHAR(64) NOT NULL,
    pattern_hash VARCHAR(64) NOT NULL UNIQUE,
    pattern_signature JSONB NOT NULL,
    description TEXT NOT NULL,
    usage_count INTEGER DEFAULT 0,
    approved_by VARCHAR(64) NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    automation_enabled BOOLEAN DEFAULT false,
    last_used_at TIMESTAMP WITH TIME ZONE,
    quarterly_review_due TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '90 days',
    review_status VARCHAR(16) DEFAULT 'pending' 
        CHECK (review_status IN ('pending', 'reviewed', 'deprecated'))
);

COMMENT ON TABLE safe_patterns IS 'Human-approved patterns eligible for automation with quarterly reviews';

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_actions_session ON agent_actions(session_id);
CREATE INDEX IF NOT EXISTS idx_agent_actions_timestamp ON agent_actions(timestamp);
CREATE INDEX IF NOT EXISTS idx_agent_actions_type ON agent_actions(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX IF NOT EXISTS idx_audit_logs_agent ON audit_logs(agent_name);
CREATE INDEX IF NOT EXISTS idx_human_approvals_status ON human_approvals(approval_status);
CREATE INDEX IF NOT EXISTS idx_human_approvals_requested ON human_approvals(requested_at);
CREATE INDEX IF NOT EXISTS idx_safe_patterns_hash ON safe_patterns(pattern_hash);
CREATE INDEX IF NOT EXISTS idx_safe_patterns_review ON safe_patterns(quarterly_review_due);

-- Create function for hash chain verification
CREATE OR REPLACE FUNCTION verify_audit_chain()
RETURNS TABLE (
    breached_entry_id UUID,
    expected_hash VARCHAR(64),
    actual_hash VARCHAR(64),
    breach_detected BOOLEAN
) AS $$
DECLARE
    prev_hash VARCHAR(64) := '0';
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT action_id, previous_hash, current_hash 
        FROM agent_actions 
        ORDER BY timestamp
    LOOP
        IF rec.previous_hash != prev_hash THEN
            RETURN QUERY SELECT 
                rec.action_id,
                prev_hash,
                rec.previous_hash,
                true;
        END IF;
        prev_hash := rec.current_hash;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Create function for auto-cleanup old audit logs (30 days)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs 
    WHERE retention_until < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to calculate risk score
CREATE OR REPLACE FUNCTION calculate_risk_score(
    action_type VARCHAR,
    files_affected TEXT[],
    agent_mode VARCHAR
)
RETURNS DECIMAL(3,1) AS $$
DECLARE
    base_score DECIMAL(3,1) := 1.0;
    file_risk DECIMAL(3,1) := 0.0;
    action_risk DECIMAL(3,1) := 0.0;
    mode_risk DECIMAL(3,1) := 0.0;
BEGIN
    -- Action type risk
    CASE action_type
        WHEN 'git-push-main' THEN action_risk := 9.0;
        WHEN 'git-merge' THEN action_risk := 8.0;
        WHEN 'rm-destructive' THEN action_risk := 8.0;
        WHEN 'docker-delete' THEN action_risk := 7.0;
        WHEN 'schema-change' THEN action_risk := 7.0;
        WHEN 'dependency-add' THEN action_risk := 6.0;
        ELSE action_risk := 3.0;
    END CASE;
    
    -- File path risk
    IF files_affected IS NOT NULL THEN
        IF array_to_string(files_affected, ',') ~ '\.github/workflows/' THEN
            file_risk := file_risk + 3.0;
        END IF;
        IF array_to_string(files_affected, ',') ~ '\.security/' THEN
            file_risk := file_risk + 3.0;
        END IF;
        IF array_to_string(files_affected, ',') ~ 'opencode\.json' THEN
            file_risk := file_risk + 2.0;
        END IF;
    END IF;
    
    -- Agent mode risk (subagents are lower risk)
    IF agent_mode = 'primary' THEN
        mode_risk := 1.0;
    ELSE
        mode_risk := 0.5;
    END IF;
    
    RETURN LEAST(base_score + action_risk + file_risk + mode_risk, 10.0);
END;
$$ LANGUAGE plpgsql;

-- Create function to increment safe pattern usage
CREATE OR REPLACE FUNCTION increment_safe_pattern_usage(pattern_hash_input VARCHAR)
RETURNS VOID AS $$
BEGIN
    UPDATE safe_patterns
    SET 
        usage_count = usage_count + 1,
        last_used_at = NOW()
    WHERE pattern_hash = pattern_hash_input;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update session end time
CREATE OR REPLACE FUNCTION update_session_end_time()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE agent_sessions
    SET ended_at = NOW()
    WHERE session_id = NEW.session_id
    AND status != 'completed';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_session_end
AFTER INSERT ON agent_actions
FOR EACH ROW
EXECUTE FUNCTION update_session_end_time();

-- Grant permissions (adjust as needed)
-- GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO aixcl_agent;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO aixcl_agent;

-- Verification: Show created tables
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public'
AND table_name IN ('agent_sessions', 'agent_actions', 'human_approvals', 'audit_logs', 'safe_patterns')
ORDER BY table_name;

-- Verification: Show created functions
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('verify_audit_chain', 'cleanup_old_audit_logs', 'calculate_risk_score', 'increment_safe_pattern_usage', 'update_session_end_time')
ORDER BY routine_name;

-- Sample queries for verification
-- SELECT 'agent_sessions' as table_name, COUNT(*) as count FROM agent_sessions;
-- SELECT 'agent_actions' as table_name, COUNT(*) as count FROM agent_actions;
-- SELECT 'audit_logs' as table_name, COUNT(*) as count FROM audit_logs;
-- SELECT * FROM verify_audit_chain();