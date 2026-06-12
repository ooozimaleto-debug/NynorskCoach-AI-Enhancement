# 📖 PROJECT CONTEXT - Full Scope & History

**This file preserves the complete project context to avoid losing information.**

---

## 🎯 Project Mission

Transform Nynorsk Coach from a generic language app into a "living" AI-powered application that:
- ✅ Understands each user personally
- ✅ Adapts content to their learning style
- ✅ Focuses on their weak areas
- ✅ Feels like a personal tutor, not a textbook

---

## 📊 Project Background

### Current Nynorsk Coach Status:
- **Foundation:** 4900 lines of quality Swift code
- **Architecture:** MVVM + SwiftUI + SwiftData
- **Features Implemented:**
  - Three mentors (Freya, Loki, Odin) with unique personalities
  - Chat system with AI mentors
  - Vision scanner for word recognition
  - RSS reader for Norwegian news
  - Gamification (XP, streaks, ranks, quests)
  - Monetization system (cosmetic store, planned Premium)
  - Widget infrastructure
  - Localization (66K words)
  - TTS (Google TTS + Audio management)
  - App Intents & Spotlight integration

### Current Problems:
1. **No Personalization:** All users see same content/prompts
2. **No Adaptation:** Difficulty doesn't adjust to user level
3. **No Smart Learning:** App doesn't know what user struggles with
4. **No Context:** Each message treated independently

### Our Solution:
Implement intelligent AI system in 4 weeks that solves all problems.

---

## 🧠 AI Architecture Overview

### Layer 1: User Context Manager
```
Purpose: Understand each user
Components:
- UserProfile (persistent, SwiftData)
- SessionContext (temporary, in-memory)
- Profile analysis & tracking
```

### Layer 2: Dynamic Content Generation
```
Purpose: Create infinite, personalized content
Components:
- ExerciseGenerator (creates exercises on-the-fly)
- StoryGenerator (personalized stories)
- Vocabulary intelligence
```

### Layer 3: Adaptive Learning
```
Purpose: System learns what user needs
Components:
- Knowledge graph (tracks mastery)
- Spaced repetition (optimal review timing)
- Weakness detection & focus
```

### Layer 4: Real-Time Interaction
```
Purpose: Make mentors respond intelligently
Components:
- Message analysis (detect errors)
- Contextual feedback (personalized corrections)
- Mood/confidence tracking
```

### Layer 5: Ambient AI
```
Purpose: Background magic
Components:
- Smart notifications (right time, right message)
- Widget intelligence (relevant content)
- Predictive engagement (nudges when needed)
```

---

## 💰 Financial Strategy

### Cost Problem:
```
If using only OpenAI GPT-4:
5000 users × 10 requests/day × 30 days × $0.0001/token
= $7500/month
```

### Cost Solution (Smart Router):
```
60% Cache hit:        $0
25% Local model:      $0  
12% Claude Haiku:     $27
3% Claude Sonnet:     $13.50
─────────────────────────
TOTAL:                ~$40-50/month
(vs $7500 - saves 99%!)
```

### Per-User Cost:
```
$40 / 5000 users = $0.008 per user per month
= Less than 1 cent per user!

Scales linearly, even at 50K users = still only $0.008/user
```

---

## 📈 4-Week Implementation Plan

### Week 1: User Context (CURRENT)
**Goal:** App understands user personality & progress

**Deliverables:**
1. UserContextManager.swift - User profile system
2. Enhanced ChatViewModel - Context-aware responses
3. Dynamic system prompts - Personalization
4. Session tracking - Progress measurement

**Outcome:** 
- User profiles created & persisted
- Each user gets personalized prompts
- System tracks weak areas & progress

**Effort:** 3-4 days

### Week 2: Dynamic Content (NEXT)
**Goal:** Infinite personalized content

**Deliverables:**
1. ExerciseGenerator.swift - AI-generated exercises
2. StoryGenerator.swift - Personalized stories
3. Adaptive quiz system - Difficulty adjustment
4. Vocabulary intelligence - Relevant vocab selection

**Outcome:**
- Users never see same exercise twice
- Content matches their level
- Stories are interesting to them
- Quizzes focus on weak areas

**Effort:** 3-4 days

### Week 3: Adaptive Learning (OPTIONAL for MVP)
**Goal:** System teaches what user needs

**Deliverables:**
1. AdaptiveLearningEngine.swift - Knowledge tracking
2. Knowledge graph - What user knows
3. Spaced repetition - Optimal review
4. Weakness detection - What to focus on

**Outcome:**
- App knows what user has learned
- Recommends next lessons automatically
- Reviews at optimal times (never forget)
- Focuses on actual weak areas

**Effort:** 3-4 days

### Week 4: Ambient AI (OPTIONAL for MVP)
**Goal:** Background magic that keeps users engaged

**Deliverables:**
1. AmbientAIManager.swift - Smart notifications
2. Widget intelligence - Relevant info
3. Predictive nudges - Engagement hooks
4. Achievement tracking - Celebratory moments

**Outcome:**
- Notifications never feel spammy
- Widgets show relevant content
- User comes back at right times
- Achievements feel earned

**Effort:** 2-3 days

---

## 🎯 Success Metrics

### Engagement:
- Daily Active Users (DAU): Target 20% of installs
- Session duration: Target 8+ minutes
- Frequency: Target 1.2x per day

### Learning:
- Lesson completion: Target 80%+
- Quiz accuracy: Target 70%+
- User progression: Advancing through levels

### Monetization:
- Free→Premium conversion: Target 5%
- Premium retention: Target 70% month 1
- ARPU: Target $2-3 per user

### Quality:
- Crash rate: <0.1%
- App rating: 4.5+ stars
- User satisfaction: NPS 50+

---

## 🛠 Technical Stack

### Swift & iOS:
- SwiftUI (UI framework)
- SwiftData (persistence)
- AVFoundation (audio)
- CoreML (local ML, optional)

### AI/API:
- OpenAI API (primary)
- Claude API (secondary)
- Local models (Mistral 7B, optional)

### Backend (Post-MVP):
- Firebase (sync, push, analytics)
- Realtime database (leaderboards)

### Infrastructure:
- Hetzner CX33 (for future agent systems)
- App Store (distribution)
- TestFlight (beta testing)

---

## 📁 File Structure

```
NynorskCoach/
├── Services/
│   ├── UserContextManager.swift (NEW - Week 1)
│   ├── ExerciseGenerator.swift (NEW - Week 2)
│   ├── AdaptiveLearningEngine.swift (NEW - Week 3)
│   ├── AmbientAIManager.swift (NEW - Week 4)
│   ├── OpenAIService.swift (existing)
│   ├── AudioManager.swift (existing)
│   └── ... (other services)
│
├── ViewModels/
│   └── ChatViewModel.swift (MODIFY - Week 1)
│
├── Views/
│   └── ChatView.swift (may need updates)
│
├── Models/
│   └── DataModels.swift (existing - Mentor enum is here)
│
└── NynorskCoachApp.swift (MODIFY - Week 1)
```

---

## 🔑 Key Concepts & Terminology

### User Learning Profile
Persistent data structure storing user's:
- Proficiency level (1-5, A1-C1)
- Learning style (visual, auditory, kinesthetic, reading/writing)
- Pace preference (slow, medium, fast)
- Weak areas (list of struggling topics)
- Progress history (sessions, XP, achievements)

### Session Context
Temporary data for current session:
- Message count
- Mistakes made
- Topics discussed
- Duration
- Correct answers count

### Context-Aware System Prompt
Dynamic instruction to AI mentor that includes:
- User's level, style, pace
- Weak areas (to focus on)
- Current streak (for motivation)
- Session history
- Personalization rules

### Knowledge Graph
Represents what user knows:
- Each topic is a node
- Success/failure tracked
- Spaced repetition timing
- Mastery level calculation

### Smart Router
Decision system that chooses AI model:
- Cache hit (60%) → $0
- Local model (25%) → $0
- Cheap API (12%) → $0.001
- Premium API (3%) → $0.01

---

## 🎓 Who's Involved

### Developer: Василий
- Location: Voss, Norway
- Background: Solo founder with EcoParse AI (ESG reporting)
- Goal: Build scalable language learning with AI
- Timeline: 4 weeks to MVP
- Language: Russian (primary), English (secondary), Norwegian (learning A1/A2)

### Project Origin:
- Previous analysis: Full iOS app code review (78MB project)
- Identified strength: Strong foundation (4900 lines quality code)
- Identified gap: No personalization/AI adaptation
- This project: Fill the gap systematically

---

## 🚀 How to Use This Document

This file serves as:
1. **Memory bank** - Full context preserved for future sessions
2. **Reference** - When you forget why we're doing something
3. **Scope clarity** - What's in/out of MVP
4. **Decision log** - Why choices were made

### When to refer to this:
- Before starting a new week
- When context gets confusing
- To explain project to others
- To remember decisions made

---

## 📝 Session History

### Session 1 (June 12, 2026):
- ✅ Analyzed existing Nynorsk Coach project
- ✅ Identified AI integration needs
- ✅ Created full 5-layer architecture
- ✅ Planned 4-week implementation
- ✅ Created all documentation (25K+ words)
- ✅ Calculated cost optimization ($7500 → $21/month)

### Session 2 (Current):
- ✅ Created organized project structure
- ✅ Modified ChatViewModel.swift
- ✅ Created UserContextManager.swift
- ✅ Updated NynorskCoachApp.swift
- ✅ Organized into Week-1 implementation
- 🔄 Currently: Implementing Week 1

---

## 🎯 Current Status

```
Week 1: User Context Management
├─ Design ........................... ✅ Complete
├─ Code Creation .................... ✅ Complete
├─ ChatViewModel.swift modification . ✅ Complete
├─ UserContextManager.swift creation . ✅ Complete
├─ NynorskCoachApp.swift update ... ✅ Complete
├─ Integration ...................... ✅ Complete
├─ Testing .......................... 🔄 In Progress
└─ Deployment to TestFlight ......... ⏳ Next

Progress: ~75% (files created, integration done, testing pending)
```

---

## ⏭️ What's Next

1. **Finish Week 1 Testing**
   - Verify compilation
   - Test user profile persistence
   - Validate dynamic prompts

2. **Start Week 2: Content Generation**
   - ExerciseGenerator
   - StoryGenerator
   - Dynamic content creation

3. **Validate in Real Usage**
   - Deploy to TestFlight
   - Get feedback from test users
   - Iterate based on feedback

4. **Scale to Production**
   - Week 3 & 4 features
   - App Store launch
   - Monitor and optimize

---

## 💡 Key Decisions Made

### Why 4 Weeks?
- Week 1: Foundation (user understanding) - critical for all others
- Week 2: Content (variety) - keeps users engaged  
- Week 3: Adaptation (smart learning) - long-term retention
- Week 4: Ambient (engagement) - lifestyle integration

### Why This Architecture?
- Modular: Each layer is independent
- Scalable: Works with 10 users or 100K
- Cost-effective: Smart routing saves 99% on API
- Maintainable: Clear separation of concerns

### Why UserContextManager First?
- Foundation for everything else
- Low risk (doesn't break existing functionality)
- High impact (enables personalization immediately)
- Clear validation path

---

## 📞 Important Contacts & Resources

### Official Docs:
- OpenAI: https://platform.openai.com/docs
- Claude: https://claude.ai/docs
- SwiftUI: Apple Developer Documentation
- SwiftData: Apple Developer Documentation

### Tools Used:
- Xcode (Swift IDE)
- Git (version control)
- Claude (AI assistant)

---

**Document Version:** 1.0  
**Last Updated:** June 12, 2026  
**Next Review:** After Week 1 completion

This document captures the full scope and context. Refer to it when needed! 🎯
