# Obsidian PDF Export - Docker Image
# Based on pandoc/extra which includes full LaTeX distribution

FROM pandoc/extra:3.1

# Install Python for preprocessing scripts (if not already available)
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-yaml 2>/dev/null || true

# Copy custom LaTeX template to Pandoc's template directory
# Pandoc looks for templates in ~/.pandoc/templates/ or /root/.pandoc/templates/
RUN mkdir -p /root/.pandoc/templates
COPY templates/obsidian.latex /root/.pandoc/templates/obsidian.latex

# Set working directory
WORKDIR /workspace

# Default entrypoint - can be overridden
ENTRYPOINT ["pandoc"]

# Default command shows help
CMD ["--help"]
