# Writing Style Guide for AI-Assisted Posts

## Author Profile
**Technical Focus**: .NET MAUI, SkiaSharp, DrawnUI, cross-platform development, game development
**Expertise Level**: Advanced practitioner and library creator
**Audience**: Developers, technical professionals
**Content Type**: Technical tutorials, deep-dive articles, implementation guides

## Voice and Tone

### Primary Characteristics
- **Conversational yet authoritative**: Speaks as peer to peer, not teacher to student
- **Practical problem-solver**: Focuses on real-world challenges and solutions
- **Enthusiastic about technology**: Shows genuine excitement about possibilities
- **Honest about limitations**: Acknowledges when approaches are experimental or have drawbacks
- **Community-oriented**: Invites feedback, contributions, and collaboration

### Tone Indicators
- Uses rhetorical questions to engage readers: "What if you want that polished game-like icon..."
- Shows personality through occasional humor and emojis (but not overdone)
- Admits uncertainty when appropriate: "This is still an experiment for a commercial app"
- Encourages reader action: "Would love to see what you build"

### Competitive Framing (keep it sharp, not sloppy)
- It's OK to contrast with other stacks (Flutter, native, etc.), but keep the wording professional and technical.
- Prefer: "same league", "comparable", "this closes the gap" backed by concrete implementation details.
- Avoid profanity or dunking; the point is capability + engineering, not drama.

## Article Structure Patterns

### Opening Strategy
1. **Context Setting**: Brief explanation of the problem space
2. **Limitation Identification**: What current solutions don't do well
3. **Value Proposition**: What the article will achieve/solve
4. **Practical Focus**: Emphasis on real-world application

### Section Organization
- **Problem → Solution → Implementation → Results** flow
- Subsections with clear, descriptive headers
- Progressive complexity (basic concepts → advanced techniques)
- Practical examples throughout, not just at the end

### Micro-Structure That Works Well
- Add a "quickly" section to control depth while signaling credibility:
	- "What we analyze (quickly)" / "How it works (briefly)" → a few bullets on the real algorithmic steps.
	- Immediately follow with "Now let’s focus on …" to move on before it turns into a DSP textbook.
- Use a "Rendering Modules" section when there’s real-time data:
	- Describe the data path (`AddSample`) separately from the paint path (`Paint`/`Render`).
	- Mention update scheduling explicitly (e.g., render returns a bool → schedule another frame).

### Closing Patterns
- **Links to resources**: Always provides relevant repository links, documentation
- **Community engagement**: Invites feedback, questions, contributions
- **Commercial awareness**: Brief mention of consulting/services when relevant
- **Future direction**: Often hints at what's coming next or areas for improvement

## Technical Writing Elements

### Code Presentation
- **Context before code**: Always explains what the code does and why
- **Real examples**: Uses actual project code, not simplified demos
- **Multiple languages**: Shows XAML, C#, XML as appropriate
- **Build integration**: Includes csproj configurations and build considerations
- **Platform differences**: Explicitly calls out Android vs iOS implementations

### Code Comment Style
- Minimal inline comments in examples
- Focuses on explaining code in surrounding text rather than comments
- Uses XML comments for build configuration explanations

### Technical Depth
- **Architecture level**: Discusses design decisions and trade-offs
- **Performance considerations**: Mentions optimization techniques and impacts
- **Troubleshooting**: Includes common pitfalls and solutions
- **Alternative approaches**: Acknowledges other ways to solve problems

### Explain the “Single Canvas” Angle in MAUI Terms
- Translate the drawn approach into MAUI-native vocabulary.
- Mention *handlers* explicitly when relevant:
	- Typical MAUI UI: many `View`s → many platform handlers (native views) → measure/layout churn and lifecycle overhead.
	- DrawnUI UI: a scene drawn into a single Skia surface (effectively one main canvas/handler) → you draw frames instead of rearranging native views.
- Use this framing especially when the post is about shaders, transitions, and realtime visualization.

### Realtime Loop Hygiene (what to emphasize)
- Call out "no per-frame allocations" and stable update scheduling when it is true.
- Describe the separation clearly:
	- Audio / input path updates state.
	- Render path paints the latest snapshot.
- If you mention a numeric range (e.g., BPM min/max), ensure it matches real code or UI constraints.

### Chronology and Cross-Links
- Never imply an upcoming article is already published.
- Use explicit phrasing:
	- "in the next article" / "upcoming" / "later I’ll show".
	- Avoid: "as I explained in the previous post" unless it is actually live.
- When referencing drafts or not-yet-released work, keep it generic (no dead links).

## Language Patterns

### Vocabulary Choices
- **Technical precision**: Uses exact technical terms (SkiaCacheType.Operations, etc.)
- **Accessibility**: Explains complex concepts in understandable terms
- **Industry terminology**: Comfortable with platform-specific terms (mipmap, Assets.xcassets)
- **Action-oriented**: Uses active voice, direct instructions

### Sentence Structure
- **Varied length**: Mixes short punchy statements with longer explanatory sentences
- **Lists and bullets**: Heavy use of structured information presentation
- **Question integration**: Rhetorical questions to maintain engagement
- **Transition clarity**: Clear connections between ideas and sections

### Paragraph Development
- **Single concept focus**: Each paragraph develops one main idea
- **Evidence support**: Claims backed by code examples or practical results
- **Progressive disclosure**: Builds complexity gradually
- **Visual breaks**: Uses code blocks, images, videos to break up text

## Content Development Approach

### Research and Examples
- **Personal experience**: Draws from actual project work and real implementations
- **Community contributions**: Acknowledges collaborators and their work
- **Multiple platforms**: Covers cross-platform considerations thoroughly
- **Version awareness**: References specific tool versions and compatibility

### Grounding and Verification Checklist
Before finalizing an article, verify:
- **Names match reality**: class names, method names, settings labels.
- **UX strings match resources** (achievement titles, button captions, etc.).
- **Counts and thresholds are not invented** (streak lengths, ranges, "X ms", etc.).
- **Code snippets match the intent** (e.g., comments don’t swap module meaning).
- **Claims about performance** are phrased as observations + reasons, not guarantees.

If uncertain, write it like:
- "In this app I’m not saving to disk; it’s monitoring + analysis".
- "This is not meant to compete with pro tools; it’s good enough for practice".

### Problem-Solution Methodology
1. **Real pain point identification**: Starts with genuine developer frustrations
2. **Current solution analysis**: Fairly evaluates existing approaches
3. **Alternative presentation**: Offers practical improvements or workarounds
4. **Implementation guidance**: Provides step-by-step instructions
5. **Validation methods**: Explains how to test and verify solutions

### Visual Integration
- **Strategic media use**: Videos and images support, don't replace, explanations
- **Code-first approach**: Shows implementation before discussing theory
- **Progressive examples**: Builds from simple to complex use cases
- **Cross-reference support**: Links between related concepts and articles

## Engagement Strategies

### Reader Interaction
- **Direct address**: Uses "you" to speak directly to reader
- **Shared experience**: Acknowledges common developer frustrations
- **Invitation to contribute**: Actively solicits feedback and contributions
- **Community building**: References other developers and their work

### Call-to-Action Patterns
- **Repository links**: Always provides access to complete source code
- **Try-it-yourself**: Encourages hands-on experimentation
- **Feedback requests**: Asks specific questions about content and approach
- **Collaboration invites**: Opens door for pull requests and improvements

## Quality Indicators

### Technical Accuracy
- **Working examples**: All code examples are from functioning projects
- **Platform testing**: Covers multiple platforms and scenarios
- **Version specificity**: References exact tool and framework versions
- **Update awareness**: Acknowledges when information may become outdated

### Practical Value
- **Immediate applicability**: Readers can implement solutions immediately
- **Production ready**: Solutions are suitable for real applications, not just demos
- **Performance conscious**: Considers resource usage and optimization
- **Maintainability focus**: Solutions that won't break with minor updates

## Anti-Patterns to Avoid

### Writing Style
- **Academic tone**: Avoid overly formal or theoretical language
- **Tutorial oversimplification**: Don't assume readers are beginners
- **Feature listing**: Avoid dry enumeration without context
- **Sales pitch tone**: Keep commercial mentions brief and relevant
- **Chronology inversion**: Don’t reference future posts as already published
- **Front matter damage**: Never leak Markdown headings into YAML front matter; keep metadata clean

### Technical Approach
- **Incomplete examples**: Always provide enough context to implement
- **Single-platform bias**: Consider cross-platform implications
- **Trend chasing**: Focus on stable, practical solutions
- **Complexity hiding**: Be honest about implementation challenges
- **Unverified specifics**: Don’t guess streak counts, thresholds, or exact algorithms if not checked in source

## Adaptation Guidelines for AI

### When mimicking this style:
1. **Start with real problems**: Identify genuine developer pain points
2. **Provide complete solutions**: Include all necessary implementation details
3. **Maintain conversational tone**: Write as experienced peer, not authority figure
4. **Include community elements**: Reference broader ecosystem and contributors
5. **Balance enthusiasm with realism**: Show excitement while acknowledging limitations
6. **Structure for scanning**: Use headers, bullets, and code blocks effectively
7. **End with engagement**: Always invite feedback and provide resources
8. **Ground the details**: Cross-check wording against code/resources before shipping

### Key phrases and expressions to incorporate:
- "What if you want..."
- "This approach gives us..."
- "The challenge was..."
- "Here's what makes this work..."
- "Would love to see what you build"
- "This is still experimental but..."
- "The real benefit is..."

### Technical depth indicators:
- Include csproj configurations
- Show platform-specific implementations
- Discuss performance implications
- Provide troubleshooting guidance
- Reference specific tool versions
- Include complete working examples