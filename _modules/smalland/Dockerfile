FROM cm2network/steamcmd:root

ENV STEAMAPPID=808040
ENV STEAMAPPDIR=/home/steam/smalland-server

RUN apt-get update \
  && apt-get install -y --no-install-recommends libsdl2-2.0-0 \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p "${STEAMAPPDIR}" \
  && chown -R steam:steam "${STEAMAPPDIR}"

COPY --chown=steam:steam entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

USER steam
WORKDIR /home/steam
EXPOSE 7777/udp 7777/tcp 7778/udp 7778/tcp
ENTRYPOINT ["/entrypoint.sh"]
