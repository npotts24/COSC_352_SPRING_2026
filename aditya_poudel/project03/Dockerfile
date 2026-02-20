FROM alpine:3.20

# tools we need: bash + docker cli + core utils
RUN apk add --no-cache bash docker-cli coreutils diffutils findutils sed grep

WORKDIR /work

# copy the grader + testdata into the image
COPY pointgrading.sh /grader/pointgrading.sh
COPY testdata /grader/testdata

RUN chmod +x /grader/pointgrading.sh

ENTRYPOINT ["/grader/pointgrading.sh"]
