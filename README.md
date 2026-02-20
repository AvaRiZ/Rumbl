# Rumbl - Video Annotation App

A real-time video annotation application built with Phoenix Framework, based on the book "Programming Phoenix 1.4" by Chris McCord, Bruce Tate, and Jose Valim.

## Features

- User registration and authentication
- Add and manage YouTube videos
- Watch videos together
- Real-time annotations using Phoenix Channels
- Categories for organizing videos

## Quick Start

### Prerequisites

- Elixir 1.15+
- PostgreSQL
- Node.js

### Setup

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Start the server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000)

### Demo Account

After running seeds, you can log in with:
- **Username:** demo
- **Password:** demo123456

## Project Structure

```
rumbl_app/
├── lib/
│   ├── rumbl/                 # Business logic
│   │   ├── accounts/          # User management
│   │   │   └── user.ex
│   │   ├── multimedia/        # Video management
│   │   │   ├── annotation.ex
│   │   │   ├── category.ex
│   │   │   └── video.ex
│   │   ├── accounts.ex        # Accounts context
│   │   └── multimedia.ex      # Multimedia context
│   │
│   └── rumbl_web/             # Web layer
│       ├── channels/          # Real-time features
│       │   ├── user_socket.ex
│       │   └── video_channel.ex
│       ├── controllers/       # HTTP handling
│       │   ├── auth.ex        # Authentication plug
│       │   ├── user_controller.ex
│       │   ├── session_controller.ex
│       │   └── video_controller.ex
│       └── router.ex          # Routes
│
├── priv/
│   └── repo/
│       ├── migrations/        # Database migrations
│       └── seeds.exs          # Seed data
│
└── assets/
    └── js/
        └── app.js             # JavaScript with video channel
```

## Key Concepts Demonstrated

### From the Book

1. **MVC with Contexts** - Business logic separated into Accounts and Multimedia contexts
2. **Authentication with Plugs** - Custom Auth plug for session management
3. **Ecto Schemas & Changesets** - Data validation and persistence
4. **Phoenix Channels** - Real-time annotations via WebSockets
5. **Generators** - Standard Phoenix resource generation patterns

### Technologies

- **Phoenix 1.8** - Web framework
- **Ecto** - Database wrapper and query language
- **Phoenix Channels** - Real-time communication
- **Bcrypt** - Password hashing
- **PostgreSQL** - Database

## Routes

| Path | Method | Description |
|------|--------|-------------|
| `/` | GET | Home page |
| `/users` | GET | List all users |
| `/users/new` | GET | Registration form |
| `/users/:id` | GET | User profile |
| `/sessions/new` | GET | Login form |
| `/sessions` | POST | Create session (login) |
| `/sessions` | DELETE | Destroy session (logout) |
| `/videos` | GET | List my videos |
| `/videos/new` | GET | Add video form |
| `/videos/:id` | GET | Video details |
| `/watch/:id` | GET | Watch video with annotations |

## Real-time Features

The `/watch/:id` page demonstrates real-time annotations:

1. User joins the video channel via WebSocket
2. When posting an annotation, it's broadcast to all viewers
3. All connected users see new annotations instantly

## Development

```bash
# Run tests
mix test

# Run with IEx for debugging
iex -S mix phx.server

# Check routes
mix phx.routes

# Reset database
mix ecto.reset
```

## Learn More

- [Phoenix Documentation](https://hexdocs.pm/phoenix/)
- [Ecto Documentation](https://hexdocs.pm/ecto/)
- [Phoenix Channels Guide](https://hexdocs.pm/phoenix/channels.html)
- [Programming Phoenix Book](https://pragprog.com/titles/phoenix14/)
