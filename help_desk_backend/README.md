# Help Desk Backend - Rails API Setup

This README provides instructions to set up the Help Desk Backend Rails API inside a Docker development environment.

---

## 1. Start the Development Environment

```bash
docker-compose up -d
```

## 2. Access the rails container

```bash
docker-compose exec web bash
```

## 3. Install Rails if not already installed

```bash
gem install rails
```

## 4. Install dependencies

```bash
bundle install
```

## 5. Create the database

```bash
cd help_desk_backend
rails db:create
```

## 6. Start the Rails Server

```bash
rails server -b 0.0.0.0 -p 3000
```

# To run tests:

## Test Requests and Services

```bash
bin/rails test test/requests/ test/services/
```

## Test Models

```bash
bin/rails test test/models
```

## Test Controllers

```bash
bin/rails test test/controllers
```
