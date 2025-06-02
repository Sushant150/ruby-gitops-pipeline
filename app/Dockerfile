
# Use official Ruby image
FROM ruby:3.2.0-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    yarn \
    tzdata \
    imagemagick \
    vips \
    git \
    curl

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy package.json and install Node dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production

# Copy application code
COPY . .

# Precompile assets
RUN RAILS_ENV=production \
    SECRET_KEY_BASE=dummy \
    DATABASE_URL=postgresql://dummy \
    bundle exec rails assets:precompile

# Create non-root user
RUN addgroup -g 1001 -S app && \
    adduser -S app -u 1001 -G app

# Create necessary directories and set permissions
RUN mkdir -p /app/tmp/pids /app/log /app/storage && \
    chown -R app:app /app

# Switch to non-root user
USER app

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
