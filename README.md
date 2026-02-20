# TaskPipeline
An asynchronous task processing system built with Phoenix, Ecto and Oban

Server runs at `http://localhost:4000`.

## Setup
```bash
mix setup
mix phx.server
```

## Environment
See `.tool-versions` for Elixir/Erlang versions.

## API Endpoints
- `GET /api/tasks` - Lists tasks (filterable by status, type, priority)
- `GET /api/tasks/:id` - Specific task details
- `GET /api/tasks/summary` - Status counts
- `POST /api/tasks` - Creates task

## Testing
```bash
mix test
```

## Architecture & Decisions
See `NOTES.md` for details.
