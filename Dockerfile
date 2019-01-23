ARG GOLANG="1.11.4"
FROM golang:$GOLANG as builder

ARG IMAGINARY_VERSION="dev"
ARG LIBVIPS_VERSION="8.7.4"

# Installs libvips + required libraries
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  automake build-essential curl \
  gobject-introspection gtk-doc-tools libglib2.0-dev libjpeg62-turbo-dev libpng-dev \
  libwebp-dev libtiff5-dev libgif-dev libexif-dev libxml2-dev libpoppler-glib-dev \
  swig libmagickwand-dev libpango1.0-dev libmatio-dev libopenslide-dev libcfitsio-dev \
  libgsf-1-dev fftw3-dev liborc-0.4-dev librsvg2-dev && \
  cd /tmp && \
  curl -OL https://github.com/libvips/libvips/releases/download/v${LIBVIPS_VERSION}/vips-${LIBVIPS_VERSION}.tar.gz && \
  tar -zxf vips-${LIBVIPS_VERSION}.tar.gz && \
  cd /tmp/vips-${LIBVIPS_VERSION} && \
  ./configure --enable-debug=no --without-python $1 && \
  make install && \
  ldconfig && \
  go get -u github.com/golang/dep/cmd/dep

# Installing gometalinter
WORKDIR /tmp
RUN curl -fsSL https://git.io/vp6lP -o instgm.sh && chmod u+x instgm.sh && ./instgm.sh -b "${GOPATH}/bin"

WORKDIR ${GOPATH}/src/github.com/h2non/imaginary

# Copy imaginary sources
COPY . .

# Making sure all dependencies are up-to-date
RUN rm -rf vendor && dep ensure

# Run quality control
RUN go test -test.v ./...
RUN gometalinter github.com/h2non/imaginary

# Compile imaginary
RUN go build -a \
    -o $GOPATH/bin/imaginary \
    -ldflags="-h -X main.Version=${IMAGINARY_VERSION}" \
    github.com/h2non/imaginary

FROM debian:stretch-slim

ARG IMAGINARY_VERSION

LABEL maintainer="tomas@aparicio.me" \
      org.label-schema.description="Fast, simple, scalable HTTP microservice for high-level image processing with first-class Docker support" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://github.com/h2non/imaginary" \
      org.label-schema.vcs-url="https://github.com/h2non/imaginary" \
      org.label-schema.version="${IMAGINARY_VERSION}"

COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /go/bin/imaginary /usr/local/bin/imaginary
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# Install runtime dependencies
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
  libglib2.0-0 libjpeg62-turbo libpng16-16 libopenexr22 \
  libwebp6 libwebpmux2 libtiff5 libgif7 libexif12 libxml2 libpoppler-glib8 \
  libmagickwand-6.q16-3 libpango1.0-0 libmatio4 libopenslide0 \
  libgsf-1-114 fftw3 liborc-0.4 librsvg2-2 libcfitsio5 && \
  apt-get autoremove -y && \
  apt-get autoclean && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Server port to listen
ENV PORT 9000

# Run the entrypoint command by default when the container starts.
ENTRYPOINT ["/usr/local/bin/imaginary"]

# Expose the server TCP port
EXPOSE ${PORT}
