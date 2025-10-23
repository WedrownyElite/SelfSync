# Self Sync Screen Flow

## Navigation Structure 🗺️

```
Home Screen
├── Log Your Mood Button → Mood Log Screen
│   └── Back Button → Home Screen
│
└── View Trends Button → Trends Screen
    └── Back Button → Home Screen
```

## Screen Details 📱

### 1. Home Screen (Entry Point)

**Purpose**: Main menu and app introduction

**Visual Elements:**
```
┌─────────────────────────────┐
│                             │
│  Self Sync 💜               │
│  Track your mood...         │
│                             │
│                             │
│  ┌─────────────────────┐   │
│  │ 📝 Log Your Mood    │   │
│  │ How are you feeling?│→  │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 📊 View Trends      │   │
│  │ Analyze patterns    │→  │
│  └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

**Interactions:**
- Tap "Log Your Mood" → Slide transition to Mood Log
- Tap "View Trends" → Scale transition to Trends

**Animations:**
- Header fades in from above
- Buttons scale in with bounce effect
- Staggered appearance (header → button 1 → button 2)

---

### 2. Mood Log Screen

**Purpose**: Record mood entries in a conversational format

**Layout:**
```
┌─────────────────────────────┐
│ ← Mood Log        3 entries │ Header
├─────────────────────────────┤
│                             │
│  😊  A bit tired but...     │ Entry 3
│      6/10 • 1h ago          │
│                             │
│  😄  Lunch was good...      │ Entry 2
│      7/10 • 3h ago          │
│                             │
│  😁  Had a great morning... │ Entry 1
│      8/10 • 6h ago          │
│                             │
├─────────────────────────────┤
│  😊 Mood: 6/10     Good     │ (Expanded)
│  ▬▬▬▬▬●▬▬▬▬▬              │ Slider
│                             │
│  [How are you feeling?] 📤 │ Input
└─────────────────────────────┘
```

**Features:**
- Reverse chronological order (newest first)
- Emoji avatar per message
- Mood badge and rating
- Smart timestamps
- Expandable input with slider

**Interactions:**
1. Tap input field → Slider expands
2. Move slider → Emoji updates in real-time
3. Type message
4. Tap send → Entry appears at top
5. List auto-scrolls to newest entry

**Animations:**
- Screen slides in from right
- Entries fade up one by one
- New entry animates in at top
- Slider expands smoothly

---

### 3. Trends Screen

**Purpose**: Visualize mood patterns and statistics

**Layout:**
```
┌─────────────────────────────┐
│ ← Mood Trends               │ Header
├─────────────────────────────┤
│  [7D][30D][3M][1Y][Lifetime]│ Time Range
├─────────────────────────────┤
│                             │
│  ┌──────────┐ ┌──────────┐ │
│  │ Average  │ │ Peak Time│ │ Stats
│  │  7.2/10  │ │  10 AM   │ │
│  └──────────┘ └──────────┘ │
│                             │
│  ┌──────────┐ ┌──────────┐ │
│  │ Best Day │ │ Toughest │ │
│  │  😁 8/10 │ │  😕 4/10 │ │
│  └──────────┘ └──────────┘ │
│                             │
│  ╭─────────────────────╮   │
│  │ 📈 Mood Trend       │   │ Chart
│  │                     │   │
│  │      ╱╲             │   │
│  │     ╱  ╲  ╱╲        │   │
│  │    ╱    ╲╱  ╲       │   │
│  ╰─────────────────────╯   │
│                             │
│  ╭─────────────────────╮   │
│  │ 📅 Activity Calendar│   │ Heatmap
│  │ ▢▢▢▢▢▢▢             │   │
│  │ ▢▢▪▪▢▢▢             │   │
│  │ ▢▪▪▪▪▢▢             │   │
│  │ Less ▢▪▪▪▪ More     │   │
│  ╰─────────────────────╯   │
└─────────────────────────────┘
```

**Features:**
- 5 time range presets
- 4 key metrics
- Line chart with custom painting
- GitHub-style activity calendar
- Empty state handling

**Interactions:**
1. Tap time range → Updates all stats
2. View scrolls → Reveals more content
3. Chart shows trend visually
4. Calendar shows activity intensity

**Animations:**
- Screen scales in with fade
- All content fades in together
- Time range tabs animate on switch

---

## User Journeys 🚶

### Journey 1: First Time User

```
1. Opens app → Home Screen
   - Reads title and subtitle
   - Sees two clear options

2. Taps "Log Your Mood" → Mood Log Screen
   - Sees empty state with guidance
   - Taps input field
   - Slider expands

3. Adjusts mood slider → Emoji changes
   - Types first message
   - Taps send

4. Entry appears → List shows 1 entry
   - Adds 2-3 more entries
   - Navigates back

5. Taps "View Trends" → Trends Screen
   - Sees stats calculated
   - Views trend chart
   - Explores time ranges
```

### Journey 2: Daily Check-in

```
1. Opens app → Home Screen
2. Taps "Log Your Mood" → Mood Log Screen
3. Reviews previous entries (scroll)
4. Adds new entry
5. Back → Home Screen
```

### Journey 3: Weekly Review

```
1. Opens app → Home Screen
2. Taps "View Trends" → Trends Screen
3. Selects "7D" range
4. Reviews average mood
5. Checks best/worst days
6. Views activity calendar
7. Switches to "30D" for comparison
```

---

## Navigation Patterns 🧭

### Forward Navigation
- Always clear which screen you'll go to
- Visual indication (arrows on buttons)
- Distinct transition per destination

### Back Navigation
- iOS-style back button (< icon + text)
- Always top-left
- Consistent across screens

### No Dead Ends
- Every screen has a way back
- No modal traps
- Clear navigation hierarchy

---

## Loading States ⏳

**Current Screens:**
- Content pre-loaded (demo data)
- Instant transitions

**Future Considerations:**
- Skeleton screens while loading
- Shimmer effects for data fetching
- Progress indicators for long operations

---

## Error States ❌

**Current Screens:**
- Empty states with guidance
- No data = helpful message

**Future Considerations:**
- Network error handling
- Data save failures
- Retry mechanisms

---

## Accessibility Flow ♿

**Navigation:**
- Semantic labels on all buttons
- Logical tab order
- Focus indicators
- Screen reader support

**Content:**
- Clear headings
- Descriptive labels
- Alternative text for icons

---

## Screen Transition Summary 🎬

| From | To | Transition | Duration |
|------|-----|-----------|----------|
| Home | Mood Log | Slide Right + Fade | 400ms |
| Mood Log | Home | Slide Left + Fade | 350ms |
| Home | Trends | Scale + Fade | 450ms |
| Trends | Home | Scale Down + Fade | 350ms |

**Why Different Durations?**
- Forward: Slightly slower (more deliberate)
- Back: Faster (returning to familiar)
- Creates rhythm and intentionality

---

## Mobile Gestures 👆

**Current:**
- Tap for navigation
- Tap for interactions
- Scroll for content

**Future Possibilities:**
- Swipe left on entry to delete
- Pull to refresh
- Long press for options
- Swipe between time ranges

---

This flow ensures users always know:
1. Where they are 📍
2. Where they can go ➡️
3. How to get back ⬅️