FROM haproxy:bookworm

USER root
# Install curl and screen (no openssl needed: TLS is terminated by Coolify/Traefik)
RUN apt-get update && apt-get install -y --no-install-recommends curl screen ca-certificates \
    && rm -rf /var/lib/apt/lists/*

USER haproxy
# Install a pinned DuckDB CLI (1.5.4's `ui` extension is not published yet -> 404)
# and bake the `ui` extension into the image so first run needs no network and
# the build fails fast if the pinned version lacks the extension.
RUN curl https://install.duckdb.org | DUCKDB_VERSION=1.5.3 sh \
    && ln -sfn /var/lib/haproxy/.duckdb/cli/1.5.3 /var/lib/haproxy/.duckdb/cli/latest \
    && /var/lib/haproxy/.duckdb/cli/latest/duckdb -c "INSTALL ui; LOAD ui;"

# Copy custom configuration file from the current directory
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY startup.sh ./startup.sh

USER root
# Make the startup script executable, and pre-create the flows dir owned by
# haproxy so a fresh (root-owned) named volume mounted here is writable.
RUN chmod +x ./startup.sh \
    && mkdir -p /var/lib/haproxy/.duckdb/extension_data \
    && chown -R haproxy:haproxy /var/lib/haproxy/.duckdb/extension_data
USER haproxy

# Plain HTTP front-end; Coolify/Traefik handles external HTTPS
EXPOSE 8080

# Command to run the application
CMD ["bash", "startup.sh"]
