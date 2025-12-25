"""3-stage LLM Council orchestration."""

from typing import List, Dict, Any, Tuple
from .config import BACKEND_MODE
from .config_manager import get_council_models, get_chairman_model

# Import appropriate backend based on configuration
if BACKEND_MODE == "ollama":
    from .ollama_adapter import query_models_parallel, query_model
else:
    from .openrouter import query_models_parallel, query_model


async def stage1_collect_responses(user_query: str) -> List[Dict[str, Any]]:
    """
    Stage 1: Collect individual responses from all council models.

    Args:
        user_query: The user's question

    Returns:
        List of dicts with 'model' and 'response' keys
    """
    print("DEBUG: stage1_collect_responses called", flush=True)
    
    # Get current council models dynamically
    council_models = await get_council_models()
    print(f"DEBUG: COUNCIL_MODELS = {council_models}", flush=True)
    print(f"DEBUG: BACKEND_MODE = {BACKEND_MODE}", flush=True)
    
    if not council_models:
        print("ERROR: No council models configured!", flush=True)
        return []
    
    # Wrap user query with instructions to provide solution, not ask questions
    solution_prompt = f"""{user_query}

CRITICAL INSTRUCTIONS:
- Solve ONLY the stated problem. Do not add extra functions or features.
- Match function signatures exactly as specified.
- Handle all edge cases mentioned (None, empty strings, whitespace, etc.).
- Provide complete, production-ready code.
- Use standard library solutions when available (e.g., s[::-1] for reversal, email.utils for email).
- Make reasonable assumptions if details are missing.
- Do NOT ask questions or request clarification.
- Do NOT read files or interpret challenge descriptions as input.
- Provide code directly, no meta-commentary."""
    
    messages = [{"role": "user", "content": solution_prompt}]
    print(f"DEBUG: messages = {messages}")

    # Query all models in parallel
    print("DEBUG: calling query_models_parallel")
    responses = await query_models_parallel(council_models, messages)
    print(f"DEBUG: query_models_parallel returned {len(responses)} responses")
    print(f"DEBUG: responses keys = {list(responses.keys())}")

    # Format results
    stage1_results = []
    failed_models = []
    for model, response in responses.items():
        print(f"DEBUG: processing model {model}, response is None: {response is None}")
        if response is not None:  # Only include successful responses
            content = response.get('content', '')
            print(f"DEBUG: model {model} content length = {len(content)}")
            stage1_results.append({
                "model": model,
                "response": content
            })
        else:
            print(f"DEBUG: model {model} returned None, skipping")
            failed_models.append(model)

    if failed_models:
        print(f"WARNING: {len(failed_models)} model(s) failed: {', '.join(failed_models)}", flush=True)
        print("This could mean:", flush=True)
        print("  1. Models are not installed in Ollama", flush=True)
        print("  2. Models are not loaded/ready", flush=True)
        print("  3. Ollama service is not responding", flush=True)
        print("  4. Check Ollama logs: docker logs ollama", flush=True)
        print("  5. Verify models exist: docker exec ollama ollama list", flush=True)

    print(f"DEBUG: stage1_collect_responses returning {len(stage1_results)} results")
    return stage1_results


async def stage2_collect_rankings(
    user_query: str,
    stage1_results: List[Dict[str, Any]]
) -> Tuple[List[Dict[str, Any]], Dict[str, str]]:
    """
    Stage 2: Each model ranks the anonymized responses.

    Args:
        user_query: The original user query
        stage1_results: Results from Stage 1

    Returns:
        Tuple of (rankings list, label_to_model mapping)
    """
    print("DEBUG: stage2_collect_rankings called")
    print(f"DEBUG: stage1_results count = {len(stage1_results)}")
    
    # Create anonymized labels for responses (Response A, Response B, etc.)
    labels = [chr(65 + i) for i in range(len(stage1_results))]  # A, B, C, ...
    print(f"DEBUG: created labels = {labels}")

    # Create mapping from label to model name
    label_to_model = {
        f"Response {label}": result['model']
        for label, result in zip(labels, stage1_results)
    }

    # Build the ranking prompt
    responses_text = "\n\n".join([
        f"Response {label}:\n{result['response']}"
        for label, result in zip(labels, stage1_results)
    ])

    ranking_prompt = f"""Evaluate code responses to this question: {user_query}

Responses (anonymized):
{responses_text}

EVALUATION CRITERIA (weighted):
1. CORRECTNESS (40%): 
   - Function signature matches requirements?
   - Solves the exact problem stated?
   - All edge cases handled?
   - No logic errors or bugs?
   - Production-ready?

2. SECURITY (20%):
   - Input validation present?
   - Injection risks prevented?
   - Safe error messages?
   - Secure coding practices?

3. CODE QUALITY (15%):
   - Documentation present?
   - Readable and clear?
   - Follows best practices?
   - Appropriate style?

4. PERFORMANCE (10%):
   - Efficient algorithm?
   - Good time/space complexity?
   - Appropriate data structures?

5. MAINTAINABILITY (10%):
   - Modular structure?
   - Easy to understand?
   - Extensible design?

6. STANDARD PRACTICES (5%):
   - Uses standard library?
   - Proven patterns?
   - Conservative approach?

RED FLAGS (rank lower):
- Wrong function signature
- Missing required functionality
- Extra unrelated functions
- Logic errors/bugs
- Misunderstanding problem (e.g., reading challenge file as input)
- Missing edge cases
- Security vulnerabilities

IMPORTANT: 
- Prefer standard solutions over experimental ones
- Flag exotic approaches
- Rank solutions that solve the exact problem highest
- Rank solutions with extra code or wrong signatures lowest
- Provide ranking only. Do not ask questions.

Evaluate each response briefly, then provide ranking:

FINAL RANKING:
1. Response X
2. Response Y
3. Response Z"""

    messages = [{"role": "user", "content": ranking_prompt}]

    # Get rankings from all council models in parallel
    print("DEBUG: calling query_models_parallel for stage2")
    council_models = await get_council_models()
    responses = await query_models_parallel(council_models, messages)
    print(f"DEBUG: stage2 query_models_parallel returned {len(responses)} responses")

    # Format results
    stage2_results = []
    for model, response in responses.items():
        if response is not None:
            full_text = response.get('content', '')
            parsed = parse_ranking_from_text(full_text)
            stage2_results.append({
                "model": model,
                "ranking": full_text,
                "parsed_ranking": parsed
            })

    return stage2_results, label_to_model


async def stage3_synthesize_final(
    user_query: str,
    stage1_results: List[Dict[str, Any]],
    stage2_results: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """
    Stage 3: Chairman synthesizes final response.

    Args:
        user_query: The original user query
        stage1_results: Individual model responses from Stage 1
        stage2_results: Rankings from Stage 2

    Returns:
        Dict with 'model' and 'response' keys
    """
    print("DEBUG: stage3_synthesize_final called", flush=True)
    
    # Get current chairman model dynamically
    chairman_model = await get_chairman_model()
    print(f"DEBUG: CHAIRMAN_MODEL = {chairman_model}", flush=True)
    print(f"DEBUG: stage1_results count = {len(stage1_results)}")
    print(f"DEBUG: stage2_results count = {len(stage2_results)}")
    
    # Build comprehensive context for chairman
    stage1_text = "\n\n".join([
        f"Model: {result['model']}\nResponse: {result['response']}"
        for result in stage1_results
    ])

    stage2_text = "\n\n".join([
        f"Model: {result['model']}\nRanking: {result['ranking']}"
        for result in stage2_results
    ])

    # Create label mapping for aggregate rankings
    labels = [chr(65 + i) for i in range(len(stage1_results))]  # A, B, C, ...
    label_to_model = {
        f"Response {label}": result['model']
        for label, result in zip(labels, stage1_results)
    }
    
    # Calculate which model was ranked highest
    aggregate_rankings = calculate_aggregate_rankings(stage2_results, label_to_model)
    top_model = aggregate_rankings[0]['model'] if aggregate_rankings else None

    chairman_prompt = f"""Synthesize the best code solution from multiple responses.

Original question: {user_query}

Individual responses:
{stage1_text}

Peer rankings:
{stage2_text}

SYNTHESIS RULES:
1. REJECT solutions that don't match function signature or solve wrong problem
2. PRIORITIZE correctness and security (mandatory)
3. PREFER solutions ranked highly by multiple models (consensus)
4. SYNTHESIZE best aspects: correctness from one, efficiency from another, clarity from a third
5. USE standard library solutions over custom code
6. FLAG exotic approaches unless explicitly requested
7. PROVIDE code directly - no preamble, no process explanations, no tool references

CRITICAL: 
- Output ONLY the code solution
- No "Given the context..." or "Based on evaluations..." 
- No meta-commentary about the council process
- Just the code that solves the problem

After the code, add two lines:
# Primary source: ModelName (or "Synthesized from multiple models" if combining)
# Confidence: XX% (your confidence this solution is correct, 0-100)

CRITICAL CONFIDENCE RULES (MUST FOLLOW):
1. Check function signature FIRST:
   - If signature doesn't match requirements (e.g., returns bool instead of tuple) → confidence MUST be 50% or below
   - If signature matches → can proceed to other checks

2. Check required functionality:
   - Missing error messages when required → subtract 20% from confidence
   - Missing normalization when required → subtract 15% from confidence
   - Missing edge case handling → subtract 10% from confidence

3. Final confidence ranges:
   - 90-100%: Perfect - signature correct, ALL requirements met, production-ready
   - 70-89%: Good - signature correct, minor issues only (missing docstring)
   - 50-69%: Partial - signature correct BUT missing key requirements
   - 30-49%: Poor - wrong signature OR multiple missing requirements
   - 0-29%: Wrong - solves different problem or critical errors

EXAMPLE: If function should return tuple[bool, str] but returns bool → confidence MUST be ≤50%

Provide the solution code directly:"""

    messages = [{"role": "user", "content": chairman_prompt}]

    # Query the chairman model
    print("DEBUG: calling query_model for chairman")
    response = await query_model(chairman_model, messages)
    print(f"DEBUG: chairman query_model returned, is None: {response is None}")

    if response is None:
        # Fallback if chairman fails
        print("DEBUG: chairman returned None, using fallback")
        return {
            "model": chairman_model,
            "response": "Error: Unable to generate final synthesis."
        }

    content = response.get('content', '')
    print(f"DEBUG: chairman content length = {len(content)}")
    print(f"DEBUG: chairman content preview = {content[:200]}")
    
    # Extract primary source model from content if present
    primary_source = None
    if "# Primary source:" in content:
        try:
            source_line = [line for line in content.split('\n') if '# Primary source:' in line][0]
            primary_source = source_line.split('# Primary source:')[1].strip()
        except (IndexError, ValueError, AttributeError):
            # If parsing fails, primary_source remains None
            pass
    
    # Extract confidence percentage from content if present
    chairman_confidence = None
    if "# Confidence:" in content:
        try:
            confidence_line = [line for line in content.split('\n') if '# Confidence:' in line][0]
            confidence_str = confidence_line.split('# Confidence:')[1].strip()
            # Extract number before % sign
            import re
            match = re.search(r'(\d+)%', confidence_str)
            if match:
                chairman_confidence = int(match.group(1))
        except (IndexError, ValueError, AttributeError):
            # If parsing fails, chairman_confidence remains None
            pass
    
    # If not found in content, use top-ranked model from Stage 2
    if not primary_source and top_model:
        primary_source = top_model
    
    # If still not found, use chairman model
    if not primary_source:
        primary_source = chairman_model
    
    # Calculate base confidence (from chairman or consensus)
    if chairman_confidence is not None:
        base_confidence = chairman_confidence
    else:
        base_confidence = 70
        if aggregate_rankings and len(aggregate_rankings) > 0:
            # Higher confidence if top model has clear lead
            top_rank = aggregate_rankings[0]['average_rank']
            if len(aggregate_rankings) > 1:
                second_rank = aggregate_rankings[1]['average_rank']
                gap = second_rank - top_rank
                # Confidence based on ranking gap (larger gap = higher confidence)
                base_confidence = min(90, max(60, 70 + int(gap * 10)))
            else:
                base_confidence = 75
    
    # ALWAYS apply correctness penalties, even if chairman provided confidence
    # Check for correctness issues in the synthesized response (content) and top-ranked response
    penalties = 0
    
    # Check synthesized response (content) for issues
    content_lower = content.lower()
    user_query_lower = user_query.lower()
    
    # Check if function signature might be wrong in synthesized response
    if '-> bool' in content_lower and 'tuple' in user_query_lower:
        penalties += 30  # Wrong return type
    if '-> str' in content_lower and 'tuple' in user_query_lower and '-> tuple' not in content_lower:
        penalties += 30  # Wrong return type
    if 'def validate_email' in content_lower and '-> tuple' not in content_lower and 'tuple' in user_query_lower:
        penalties += 30  # Missing tuple return type annotation
    
    # Check for missing error messages in return statements
    if 'return false' in content_lower or 'return true' in content_lower:
        if 'tuple' in user_query_lower and '(' not in content.split('return')[1][:20] if 'return' in content else '':
            penalties += 20  # Missing tuple return (should return (False, "message"))
    
    # Check for missing normalization when required
    if 'normalize' in user_query_lower or 'lowercase' in user_query_lower:
        if 'lower()' not in content_lower and 'lowercase' in user_query_lower:
            penalties += 15  # Missing lowercase normalization
        if 'strip()' not in content_lower and 'trim' in user_query_lower:
            penalties += 10  # Missing whitespace trimming
    
    # Also check top-ranked response for additional context
    if top_model and stage1_results:
        top_response = next((r for r in stage1_results if r['model'] == top_model), None)
        if top_response:
            response_text = top_response.get('response', '').lower()
            
            # Additional penalties if top response has issues
            if '-> bool' in response_text and 'tuple' in user_query_lower:
                penalties += 10  # Top response also has wrong signature
            if 'return false' in response_text and 'tuple' in user_query_lower:
                penalties += 5  # Top response missing tuple return
    
    # Apply penalties (always, even if chairman provided confidence)
    confidence = max(30, base_confidence - penalties)
    
    # Log penalty application for debugging
    if penalties > 0:
        print(f"DEBUG: Applied {penalties}% penalty to confidence. Base: {base_confidence}%, Final: {confidence}%", flush=True)
    
    return {
        "model": chairman_model,
        "response": content,
        "primary_source": primary_source,
        "top_ranked_model": top_model,
        "confidence": confidence
    }


def parse_ranking_from_text(ranking_text: str) -> List[str]:
    """
    Parse the FINAL RANKING section from the model's response.

    Args:
        ranking_text: The full text response from the model

    Returns:
        List of response labels in ranked order
    """
    import re

    # Look for "FINAL RANKING:" section
    if "FINAL RANKING:" in ranking_text:
        # Extract everything after "FINAL RANKING:"
        parts = ranking_text.split("FINAL RANKING:")
        if len(parts) >= 2:
            ranking_section = parts[1]
            # Try to extract numbered list format (e.g., "1. Response A")
            # This pattern looks for: number, period, optional space, "Response X"
            numbered_matches = re.findall(r'\d+\.\s*Response [A-Z]', ranking_section)
            if numbered_matches:
                # Extract just the "Response X" part
                return [re.search(r'Response [A-Z]', m).group() for m in numbered_matches]

            # Fallback: Extract all "Response X" patterns in order
            matches = re.findall(r'Response [A-Z]', ranking_section)
            return matches

    # Fallback: try to find any "Response X" patterns in order
    matches = re.findall(r'Response [A-Z]', ranking_text)
    return matches


def calculate_aggregate_rankings(
    stage2_results: List[Dict[str, Any]],
    label_to_model: Dict[str, str]
) -> List[Dict[str, Any]]:
    """
    Calculate aggregate rankings across all models.

    Args:
        stage2_results: Rankings from each model
        label_to_model: Mapping from anonymous labels to model names

    Returns:
        List of dicts with model name and average rank, sorted best to worst
    """
    from collections import defaultdict

    # Track positions for each model
    model_positions = defaultdict(list)

    for ranking in stage2_results:
        ranking_text = ranking['ranking']

        # Parse the ranking from the structured format
        parsed_ranking = parse_ranking_from_text(ranking_text)

        for position, label in enumerate(parsed_ranking, start=1):
            if label in label_to_model:
                model_name = label_to_model[label]
                model_positions[model_name].append(position)

    # Calculate average position for each model
    aggregate = []
    for model, positions in model_positions.items():
        if positions:
            avg_rank = sum(positions) / len(positions)
            aggregate.append({
                "model": model,
                "average_rank": round(avg_rank, 2),
                "rankings_count": len(positions)
            })

    # Sort by average rank (lower is better)
    aggregate.sort(key=lambda x: x['average_rank'])

    return aggregate


async def generate_conversation_title(user_query: str) -> str:
    """
    Generate a short title for a conversation based on the first user message.

    Args:
        user_query: The first user message

    Returns:
        A short title (3-5 words)
    """
    title_prompt = f"""Generate a very short title (3-5 words maximum) that summarizes the following question.
The title should be concise and descriptive. Do not use quotes or punctuation in the title.

Question: {user_query}

Title:"""

    messages = [{"role": "user", "content": title_prompt}]

    # Use chairman model for title generation
    chairman_model = await get_chairman_model()
    response = await query_model(chairman_model, messages, timeout=30.0)

    if response is None:
        # Fallback to a generic title
        return "New Conversation"

    title = response.get('content', 'New Conversation').strip()

    # Clean up the title - remove quotes, limit length
    title = title.strip('"\'')

    # Truncate if too long
    if len(title) > 50:
        title = title[:47] + "..."

    return title


async def run_full_council(user_query: str) -> Tuple[List, List, Dict, Dict]:
    """
    Run the complete 3-stage council process.

    Args:
        user_query: The user's question

    Returns:
        Tuple of (stage1_results, stage2_results, stage3_result, metadata)
    """
    print("DEBUG: run_full_council called", flush=True)
    print(f"DEBUG: user_query = {user_query[:100]}...", flush=True)
    
    # Stage 1: Collect individual responses
    print("DEBUG: starting stage1")
    stage1_results = await stage1_collect_responses(user_query)
    print(f"DEBUG: stage1 completed, results count = {len(stage1_results)}")

    # If no models responded successfully, return error
    if not stage1_results:
        print("ERROR: stage1_results is empty - all models failed!", flush=True)
        print("Troubleshooting steps:", flush=True)
        print("  1. Check if Ollama is running: docker ps | grep ollama", flush=True)
        print("  2. Check Ollama logs: docker logs ollama", flush=True)
        print("  3. Verify models are installed: docker exec ollama ollama list", flush=True)
        print("  4. Check council models in .env: COUNCIL_MODELS and CHAIRMAN_MODEL", flush=True)
        print("  5. Test a model directly: docker exec ollama ollama run <model-name> 'test'", flush=True)
        error_result = {
            "model": "error",
            "response": "All models failed to respond. Please check:\n1. Ollama service is running\n2. Models are installed and available\n3. Check logs: docker logs ollama\n4. Verify models: docker exec ollama ollama list"
        }
        print(f"DEBUG: returning error_result = {error_result}")
        return [], [], error_result, {}

    # Stage 2: Collect rankings
    print("DEBUG: starting stage2")
    stage2_results, label_to_model = await stage2_collect_rankings(user_query, stage1_results)
    print(f"DEBUG: stage2 completed, results count = {len(stage2_results)}")

    # Calculate aggregate rankings
    aggregate_rankings = calculate_aggregate_rankings(stage2_results, label_to_model)
    print(f"DEBUG: aggregate_rankings = {aggregate_rankings}")

    # Stage 3: Synthesize final answer
    print("DEBUG: starting stage3")
    stage3_result = await stage3_synthesize_final(
        user_query,
        stage1_results,
        stage2_results
    )
    print(f"DEBUG: stage3 completed, result = {stage3_result}")

    # Prepare metadata
    metadata = {
        "label_to_model": label_to_model,
        "aggregate_rankings": aggregate_rankings
    }

    print("DEBUG: run_full_council returning")
    return stage1_results, stage2_results, stage3_result, metadata
