# Use the official Go 1.23-alpine image as base (latest stable)
FROM golang:1.23-alpine AS builder

# Set working directory inside the container
WORKDIR /app

# Install necessary packages for building
RUN apk add --no-cache git

# Copy go.mod and go.sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Start a new stage from alpine for smaller final image
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create app directory
WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Expose port 8000
EXPOSE 8000

# Command to run the application
CMD ["./main"]
