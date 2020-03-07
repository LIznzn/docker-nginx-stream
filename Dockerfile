FROM alpine:3.11.3

ENV nginx_version 1.17.9
ENV openssl_version 1.1.1.c
ENV zlib_version 1.2.11
ENV pcre_version 8.43
ENV geoip_version 1.6.12

ENV build_packages "git g++ curl make libtool autoconf automake linux-headers"

RUN apk update \
        && apk add --no-cache $build_packages \
        && apk upgrade \
        && cd /tmp \
        && wget http://zlib.net/zlib-$zlib_version.tar.gz \
        && wget https://ftp.pcre.org/pub/pcre/pcre-$pcre_version.tar.gz \
        && tar -zxf zlib-$zlib_version.tar.gz \
        && tar -zxf pcre-$pcre_version.tar.gz \
        && git clone https://github.com/maxmind/geoip-api-c -b v$geoip_version --depth=1 \
        && git clone https://github.com/LIznzn/ngx_stream_upstream_dynamic_module.git --depth=1 \
        && git clone https://github.com/nginx/nginx.git -b release-$nginx_version --depth=1 \
        && git clone https://salsa.debian.org/debian/openssl.git -b debian/unstable --depth=1 \
        && rm *.tar.gz \
        && cd /tmp/geoip-api-c \
        && ./bootstrap \
        && ./configure && make -j4 && make install \
        && cd /tmp/nginx \
        && ./auto/configure --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat \ 
           -Werror=format-security -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro' \
           --prefix=/usr/local/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log \
           --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid \
           --without-http --with-stream --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module \
           --add-module=/tmp/ngx_stream_upstream_dynamic_module --with-openssl=/tmp/openssl \
           --with-zlib=/tmp/zlib-$zlib_version --with-threads \
        && make -j4 && make install \
        && rm -rf /tmp/* \
        && apk del $build_packages

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log 

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]