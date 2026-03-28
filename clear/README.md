# Clear

Clear is a planner web app for students to see how different choices in their semester/quarter affect their workload, stress, and grades.
It features AI integration, collaboration with others, and an intuitive UI for everyone.

## Core Features

- Authentication with "devise" + "devise_invitable"
- Personal dashboard with schedule/agenda views
- Events with recurrence support ("repeat_days", "repeat_until") 
- Course management with class meetings and course items (assignments, quizzes, exams, etc.)
- Syllabus upload + parsing (PDF/DOCX extraction to course/course-item drafts)
- University calendar RSS importing for events
- In-app notifications and reminder generation
- AI chat assistant (Gemini) with event creation/editing tool-calls
- User customization with custom avatars and numerous options for themes
- Admin users page

## Tech Stack

- Ruby "3.4.7"
- Rails "8.1.x"
- PostgreSQL
- Tailwind CSS 4 + esbuild
- Hotwire (Turbo + Stimulus)
- Active Storage (local in development)

## Prerequisites

Install before setup:

- Ruby "3.4.7"
- Node "22.21.1"
- PostgreSQL (running locally)
- Yarn
- Mise

## Local Setup

1. Install dependencies and prepare DB:

```bash
bundle install
npm install
bin/rails db:migrate
bin/rails stimulus:manifest:update
npm run build
```

2. Configure environment variables (`.env`) as needed:

```bash
GEMINI_API_KEY=your_key_here
GEMINI_MODEL=gemini-2.5-flash
```

Notes:

- Gemini is the active AI backend used by "AiChatController".
- "OllamaClient" exists in the codebase but is not currently wired into the chat controller.

3. Start the app:

```bash
bin/dev
```

Open: `http://localhost:3000`

## Database + Seeds

```bash
bin/rails db:seed
```

## Lint and Security Checks

```bash
bin/rubocop
bundle audit
yarn audit
```

## Key Routes

- `/` landing page (or dashboard when authenticated)
- `/dashboard`
- `/events`
- `/courses`
- `/courses/:course_id/course_items`
- `/syllabuses`
- `/projects`
- `/ai_chat`
- `/notifications`
- `/admin/users` (admin-only)
