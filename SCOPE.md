# PantryPal v1 — Scoping



## Scope committed

* **Conversational cooking assistant:** Native SwiftUI chat backed by a Next.js + Fastify Node.js backend using the Vercel AI SDK. Responses stream into the UI so the experience feels conversational and responsive rather than like a traditional request/response API.
* **Recipe and kitchen-fit assistance:** Users can provide the ingredients and cooking equipment they have. Before recommending a recipe, the assistant can use a deterministic kitchen-checking tool to identify missing ingredients/equipment and suggest a workaround or alternative rather than simply rejecting the recipe.
* **Model-driven tool use:** The model decides when external information is useful and can invoke web search(Brave). Tools are not executed in a hardcoded sequence.
* **Food-focused personality and guardrails:** PantryPal has an opinionated, friendly “friend who cooks” voice. Food and food-adjacent topics are supported; clearly unrelated requests are politely redirected. 
* **Safety/compliance baseline:** Medical-condition-specific dietary advice and individualized food-safety determinations are declined. A consistent allergen notice is rendered by the application rather than relying on the model to remember it. 
* **Usable native experience:** SwiftUI chat supports streaming, loading/error states.
* **Accessibility Concerns:** Font size selection. 

## Scope cut
* **Persistent cross-session conversational memory:** Valuable product functionality, but deferred because retaining dietary/health-related information requires an explicit retention/deletion policy that is unresolved in the brief. Kitchen equipment may be stored locally because it is required for recipe feasibility and is not health information.
* **PDF/family cookbook ingestion and RAG:** Explicitly identified by CX as something that does not need to be solved for v1. It would add ingestion, chunking, retrieval, storage, and failure modes without improving the core 6 PM cooking experience enough for this time box.
* **Voice/hands-free cooking:** Strategically valuable but not required for v1. The backend remains API-driven so a future voice client can reuse the same conversational/tool layer.
* **Favorites and grocery-list export:** Repeatedly requested by users, but secondary to producing trustworthy recipe recommendations and a reliable chat experience.
* **Database/Postgres:** The committed scope does not require server persistence, so introducing operational and schema complexity is not justified for this build.

## Contradictions resolved

* **Strict cooking-only vs. broad food-adjacent scope:** Support cooking and reasonable food-adjacent questions such as ingredient substitutions, cookware, hosting, and food-related recommendations, while redirecting clearly unrelated requests. This preserves the product identity without making the guardrail unnecessarily rigid.
* **Health-aware personalization vs. legal restrictions:** PantryPal may respect ordinary stated preferences such as vegetarian food or cuisine preferences, but it will not provide recommendations claiming suitability for diabetes, pregnancy, allergies as medical treatment, or other health conditions. Health-condition questions receive a brief recommendation to consult an appropriate professional.
* **Two-second responses vs. answer quality/tool usage:** Optimize for fast time-to-first-token using streaming rather than interpreting two seconds as a guarantee that every complete answer finishes in two seconds. External searches may take longer when the model determines fresh information is necessary.
* **Strong personality vs. compliance notices:** Personality remains in the generated cooking response, while legally required allergen messaging is rendered consistently by the product UI rather than delegated to the model.

## Clarifying questions

* What exact information is PantryPal permitted to retain across sessions, and what deletion controls are required before persistent memory can ship?
* Does the two-second performance requirement mean time to first visible response or completion of the entire response?
* Which source or authority should PantryPal direct users to for food-safety questions, and what exact legal-approved language should be used for medical/dietary redirection and allergen notices?
* For production, should pantry ingredients represent current consumable inventory or simply ingredients the user commonly keeps available?

## Assumptions made

* Users will explicitly provide the cookware/equipment and pantry ingredients they currently have rather than PantryPal assuming a universal starter kitchen.
* Missing equipment should produce substitutions or alternate recipe suggestions whenever practical rather than a dead-end refusal.
* Web search is useful for information requiring external/current context, but normal cooking knowledge should not automatically trigger an external request.
* Local development and evaluator usability are more important than hosted infrastructure for this version, consistent with the assessment instructions.

## Risks accepted

* Safety and scope behavior are primarily enforced through strong model instructions, with deterministic handling reserved for the allergen notice. A production implementation would add more comprehensive policy evaluation and automated adversarial testing.
* Pantry/ equipment information supplied by the user may be incomplete or inaccurate, so kitchen-feasibility results can only be as accurate as the profile provided.
* No persistent conversation history means full continuity across terminated app sessions is not available in this build.
* The time-to-first-token target can be optimized but cannot be guaranteed under all model, network, or external-tool conditions.

