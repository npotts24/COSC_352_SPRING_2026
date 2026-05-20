# Use Alpine Linux
FROM alpine:latest

# Install bash
RUN apk add --no-cache bash

# Copy program
COPY program.sh /program.sh

# Make program executable
RUN chmod +x /program.sh

# Run program by default
CMD ["/bin/bash", "/program.sh"]
