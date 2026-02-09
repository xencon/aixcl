"""3-stage LLM Council orchestration."""

import logging
import re
from typing import List, Dict, Any, Tuple
from .config import BACKEND_MODE
from .config_manager import get_council_models, get_chairman_model

logger = logging.getLogger(__name__)

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
    logger.debug("stage1_collect_responses called")
    
    # Get current council models dynamically
    council_models = await get_council_models()
    logger.debug("COUNCIL_MODELS = %s", council_models)
    logger.debug("BACKEND_MODE = %s", BACKEND_MODE)
    
    if not council_models:
        logger.error("No council models configured!")
        return []
    
    # Wrap user query with instructions for plain-text responses
    solution_prompt = f"""{user_query}

RESPONSE GUIDANCE:
- Answer directly. Lead with the answer, not preamble or restatement of the question.
- Use plain text unless the user explicitly asks for code.
- If code is explicitly requested, provide only the code without extra commentary.
- Keep responses concise. Use bullet points for lists, short paragraphs for prose.
- Make reasonable assumptions if details are missing.
- Do NOT ask questions or request clarification.
- Do NOT add disclaimers, caveats, or offers of further help.
- Do NOT reference tools, files, or the council process."""
    
    messages = [{"role": "user", "content": solution_prompt}]

    # Query all models in parallel
    logger.debug("calling query_models_parallel")
    responses = await query_models_parallel(council_models, messages)
    logger.debug("query_models_parallel returned %d responses", len(responses))

    # Format results
    stage1_results = []
    failed_models = []
    for model, response in responses.items():
        if response is not None:  # Only include successful responses
            content = response.get('content', '')
            logger.debug("model %s content length = %d", model, len(content))
            stage1_results.append({
                "model": model,
                "response": content,
                "prompt_tokens": response.get('prompt_tokens', 0),
                "completion_tokens": response.get('completion_tokens', 0),
            })
        else:
            logger.debug("model %s returned None, skipping", model)
            failed_models.append(model)

    if failed_models:
        logger.warning(
            "%d model(s) failed: %s. Check: 1) Models installed in Ollama, "
            "2) Models loaded/ready, 3) Ollama service responding, "
            "4) Ollama logs: docker logs ollama, "
            "5) Verify models: docker exec ollama ollama list",
            len(failed_models), ', '.join(failed_models)
        )

    logger.debug("stage1_collect_responses returning %d results", len(stage1_results))
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
    logger.debug("stage2_collect_rankings called")
    logger.debug("stage1_results count = %d", len(stage1_results))
    
    # Create anonymized labels for responses (Response A, Response B, etc.)
    labels = [chr(65 + i) for i in range(len(stage1_results))]  # A, B, C, ...
    logger.debug("created labels = %s", labels)

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

    ranking_prompt = f"""Evaluate responses to this question: {user_query}

Responses (anonymized):
{responses_text}

First determine whether the user explicitly requested code. Use the criteria that match the request type:
- If code was requested, apply CODE CRITERIA.
- If code was not requested, apply PLAIN TEXT CRITERIA and do not penalize responses for lacking code.

PLAIN TEXT CRITERIA (weighted):
1. CORRECTNESS (45%):
   - Directly answers the request?
   - Accurate and free of factual errors?
   - No contradictions?
2. COMPLETENESS (20%):
   - Covers key requirements?
   - Reasonable assumptions stated?
   - Handles edge cases when relevant?
3. CLARITY (15%):
   - Clear structure and concise wording?
   - Easy to follow?
4. SAFETY/SECURITY (10%):
   - Avoids unsafe guidance?
   - Notes risks or limitations when important?
5. PRACTICALITY (10%):
   - Actionable and useful?
   - No unnecessary extras?

CODE CRITERIA (weighted):
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
- For plain text requests:
  - Does not answer the question
  - Incorrect or misleading content
  - Requests clarification or asks questions
  - Provides code when code was not requested
- For code requests:
  - Wrong function signature
  - Missing required functionality
  - Extra unrelated functions
  - Logic errors/bugs
  - Missing edge cases
  - Security vulnerabilities
  - No code provided

IMPORTANT:
- Apply only the criteria that match the request type.
- Prefer standard solutions over experimental ones.
- Flag exotic approaches.
- Rank solutions that solve the exact problem highest.
- Provide ranking only. Do not ask questions.

Evaluate each response briefly, then provide ranking:

FINAL RANKING:
1. Response X
2. Response Y
3. Response Z"""

    messages = [{"role": "user", "content": ranking_prompt}]

    # Get rankings from all council models in parallel
    logger.debug("calling query_models_parallel for stage2")
    council_models = await get_council_models()
    responses = await query_models_parallel(council_models, messages)
    logger.debug("stage2 query_models_parallel returned %d responses", len(responses))

    # Format results
    stage2_results = []
    for model, response in responses.items():
        if response is not None:
            full_text = response.get('content', '')
            parsed = parse_ranking_from_text(full_text)
            stage2_results.append({
                "model": model,
                "ranking": full_text,
                "parsed_ranking": parsed,
                "prompt_tokens": response.get('prompt_tokens', 0),
                "completion_tokens": response.get('completion_tokens', 0),
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
    logger.debug("stage3_synthesize_final called")
    
    # Get current chairman model dynamically
    chairman_model = await get_chairman_model()
    logger.debug("CHAIRMAN_MODEL = %s", chairman_model)
    logger.debug("stage1_results count = %d", len(stage1_results))
    logger.debug("stage2_results count = %d", len(stage2_results))
    
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

    chairman_prompt = f"""Synthesize the best response from multiple responses.

Original question: {user_query}

Individual responses:
{stage1_text}

Peer rankings:
{stage2_text}

SYNTHESIS RULES:
1. PRIORITIZE correctness and security (mandatory)
2. PREFER responses ranked highly by multiple models (consensus)
3. SYNTHESIZE best aspects: accuracy from one, clarity from another, brevity from a third
4. USE plain text unless the user explicitly asked for code
5. If code is requested, provide code only (no preamble, no process explanations)
6. NEVER add meta-commentary about the council process, model names, or how the answer was produced
7. Do NOT restate the question. Do NOT add disclaimers or offers of further help
8. Keep the response concise. Use bullet points for lists, short paragraphs for prose

After the response, add exactly two metadata lines (these will be stripped from user-facing output):
# Primary source: ModelName (or "Synthesized from multiple models" if combining)
# Confidence: XX% (your confidence this response is correct, 0-100)

Provide the response directly:"""

    messages = [{"role": "user", "content": chairman_prompt}]

    # Query the chairman model
    logger.debug("calling query_model for chairman")
    response = await query_model(chairman_model, messages)
    logger.debug("chairman query_model returned, is None: %s", response is None)

    if response is None:
        # Fallback if chairman fails
        logger.warning("Chairman model returned None, using fallback")
        return {
            "model": chairman_model,
            "response": "Error: Unable to generate final synthesis."
        }

    content = response.get('content', '')
    chairman_prompt_tokens = response.get('prompt_tokens', 0)
    chairman_completion_tokens = response.get('completion_tokens', 0)
    logger.debug("chairman content length = %d, prompt_tokens = %d, completion_tokens = %d",
                 len(content), chairman_prompt_tokens, chairman_completion_tokens)
    
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
    
    # Determine confidence from chairman self-report or consensus-based fallback
    if chairman_confidence is not None:
        confidence = chairman_confidence
    else:
        confidence = 70
        if aggregate_rankings and len(aggregate_rankings) > 0:
            # Higher confidence if top model has clear lead in rankings
            top_rank = aggregate_rankings[0]['average_rank']
            if len(aggregate_rankings) > 1:
                second_rank = aggregate_rankings[1]['average_rank']
                gap = second_rank - top_rank
                # Confidence based on ranking gap (larger gap = higher confidence)
                confidence = min(90, max(60, 70 + int(gap * 10)))
            else:
                confidence = 75
    
    return {
        "model": chairman_model,
        "response": content,
        "primary_source": primary_source,
        "top_ranked_model": top_model,
        "confidence": confidence,
        "prompt_tokens": chairman_prompt_tokens,
        "completion_tokens": chairman_completion_tokens,
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
    logger.debug("run_full_council called")
    logger.debug("user_query = %.100s...", user_query)
    
    # Stage 1: Collect individual responses
    logger.debug("starting stage1")
    stage1_results = await stage1_collect_responses(user_query)
    logger.debug("stage1 completed, results count = %d", len(stage1_results))

    # If no models responded successfully, return error
    if not stage1_results:
        logger.error(
            "stage1_results is empty - all models failed! "
            "Check: 1) Ollama running, 2) Ollama logs, 3) Models installed, "
            "4) COUNCIL_MODELS and CHAIRMAN_MODEL in .env, "
            "5) Test model directly: docker exec ollama ollama run <model> 'test'"
        )
        error_result = {
            "model": "error",
            "response": "All models failed to respond. Please check:\n1. Ollama service is running\n2. Models are installed and available\n3. Check logs: docker logs ollama\n4. Verify models: docker exec ollama ollama list"
        }
        return [], [], error_result, {}

    # Stage 2: Collect rankings
    logger.debug("starting stage2")
    stage2_results, label_to_model = await stage2_collect_rankings(user_query, stage1_results)
    logger.debug("stage2 completed, results count = %d", len(stage2_results))

    # Calculate aggregate rankings
    aggregate_rankings = calculate_aggregate_rankings(stage2_results, label_to_model)
    logger.debug("aggregate_rankings = %s", aggregate_rankings)

    # Stage 3: Synthesize final answer
    logger.debug("starting stage3")
    stage3_result = await stage3_synthesize_final(
        user_query,
        stage1_results,
        stage2_results
    )
    logger.debug("stage3 completed")

    # Accumulate token usage across all council stages
    total_prompt_tokens = (
        sum(r.get('prompt_tokens', 0) for r in stage1_results) +
        sum(r.get('prompt_tokens', 0) for r in stage2_results) +
        stage3_result.get('prompt_tokens', 0)
    )
    total_completion_tokens = (
        sum(r.get('completion_tokens', 0) for r in stage1_results) +
        sum(r.get('completion_tokens', 0) for r in stage2_results) +
        stage3_result.get('completion_tokens', 0)
    )
    logger.debug("Total token usage: prompt=%d, completion=%d",
                 total_prompt_tokens, total_completion_tokens)

    # Prepare metadata
    metadata = {
        "label_to_model": label_to_model,
        "aggregate_rankings": aggregate_rankings,
        "total_prompt_tokens": total_prompt_tokens,
        "total_completion_tokens": total_completion_tokens,
    }

    logger.debug("run_full_council returning")
    return stage1_results, stage2_results, stage3_result, metadata
