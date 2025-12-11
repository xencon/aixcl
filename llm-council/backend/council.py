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
    
    messages = [{"role": "user", "content": user_query}]
    print(f"DEBUG: messages = {messages}")

    # Query all models in parallel
    print("DEBUG: calling query_models_parallel")
    responses = await query_models_parallel(council_models, messages)
    print(f"DEBUG: query_models_parallel returned {len(responses)} responses")
    print(f"DEBUG: responses keys = {list(responses.keys())}")

    # Format results
    stage1_results = []
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

    ranking_prompt = f"""You are evaluating different responses to the following question:

Question: {user_query}

Here are the responses from different models (anonymized):

{responses_text}

Your task:
1. First, evaluate each response individually. For each response, explain what it does well and what it does poorly.
2. Then, at the very end of your response, provide a final ranking.

IMPORTANT: Your final ranking MUST be formatted EXACTLY as follows:
- Start with the line "FINAL RANKING:" (all caps, with colon)
- Then list the responses from best to worst as a numbered list
- Each line should be: number, period, space, then ONLY the response label (e.g., "1. Response A")
- Do not add any other text or explanations in the ranking section

Example of the correct format for your ENTIRE response:

Response A provides good detail on X but misses Y...
Response B is accurate but lacks depth on Z...
Response C offers the most comprehensive answer...

FINAL RANKING:
1. Response C
2. Response A
3. Response B

Now provide your evaluation and ranking:"""

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

    chairman_prompt = f"""You are the Chairman of an LLM Council. Multiple AI models have provided responses to a user's question, and then ranked each other's responses.

Original Question: {user_query}

STAGE 1 - Individual Responses:
{stage1_text}

STAGE 2 - Peer Rankings:
{stage2_text}

Your task as Chairman is to synthesize all of this information into a single, comprehensive, accurate answer to the user's original question. Consider:
- The individual responses and their insights
- The peer rankings and what they reveal about response quality
- Any patterns of agreement or disagreement

Provide a clear, well-reasoned final answer that represents the council's collective wisdom:"""

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
    
    return {
        "model": chairman_model,
        "response": content
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
        print("DEBUG: WARNING - stage1_results is empty, returning error")
        error_result = {
            "model": "error",
            "response": "All models failed to respond. Please try again."
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
