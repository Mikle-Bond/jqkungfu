# syntax=docker/dockerfile-upstream:master-labs
FROM emscripten/emsdk:3.1.8 as builder

RUN apt-get update && apt-get install -y autoconf libtool

ADD --keep-git-dir=false https://github.com/stedolan/jq.git /src
WORKDIR /src
COPY jq.patch .

RUN <<-EOF
	# Edit main.c so that reset option flags to 0 every time we call the main() function
	# This is needed because we're not exiting after each main() call; otherwise, the
	# "Sort Keys" feature wouldn't work
	patch -p1 < jq.patch

	# Generate ./configure file
	autoreconf -fi

	# Run ./configure
	emconfigure ./configure `
	` --with-oniguruma=builtin `
	` --disable-maintainer-mode `
	`

	# Compile jq and generate .js/.wasm files
	emmake make `
	` EXEEXT=.js `
	` CFLAGS="-O2 -s EXPORTED_RUNTIME_METHODS=['callMain']" `
	`

	#mv jq.{js,wasm} ../build/
EOF

FROM busybox as static

WORKDIR /app

RUN mkdir -p /app/build

COPY --from=builder /src/jq.js /src/jq.wasm /app/build/
COPY index.html loading.gif /app

FROM halverneus/static-file-server:latest

EXPOSE 3000
ENV PORT=3000 \
	FOLDER=/app \
	CORS=true

COPY --from=static /app /app

