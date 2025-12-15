## Summary

This PR fixes the continue plugin integration by creating a separate database for continue conversations, ensuring the admin database remains untouched.

## Changes

- Created separate "continue" database for continue plugin conversations
- Updated configuration to use POSTGRES_CONTINUE_DATABASE environment variable
- Modified db.py to connect to continue database instead of admin database
- Fixed API error responses to include both id and conversation_id fields
- Updated test scripts to handle error responses and verify database integration
- Fixed council configuration to match available models
- Optimized council member tests with reduced timeout

## Test Results

- ✅ All tests passing: 44 passed, 0 failed, 1 skipped
- ✅ Continue database integration verified
- ✅ Admin database untouched (0 chats)
- ✅ All council models operational

## Key Files Modified

- llm-council/backend/config.py: Added POSTGRES_CONTINUE_DATABASE config
- llm-council/backend/db.py: Updated to use continue database
- llm-council/backend/main.py: Fixed error response format
- services/docker-compose.yml: Updated default model configuration
- tests/end-to-end-tests.sh: Improved dependency handling
- llm-council/scripts/test/test_continue_integration.py: Handle error responses
- llm-council/scripts/test_council_members.py: Reduced timeout

