FROM perl-base:latest

########################################################################
# Apache
########################################################################
RUN yum install -y httpd mod_perl perl-libapreq2

########################################################################
# Additional yum packages for this application
########################################################################
RUN yum install -y libtidyp libtidyp-devel

########################################################################
# Perl dependencies - application
########################################################################

COPY requires .
RUN for a in $(cat requires | grep -v '^#'); do \
      cpanm -n -v $a || false; \
    done

########################################################################
# Syntax::SourceHighlight
########################################################################
RUN yum install -y source-highlight source-highlight-devel

RUN libboost=$(find /usr/lib64 -name 'libboost_regex.so*'); \
    ln -s $libboost $(echo $libboost | sed 's/\.so.*/.so/')
COPY Syntax-SourceHighlight-master.tar.gz .
RUN tar xfvz Syntax-SourceHighlight-master.tar.gz; \
    cd Syntax-SourceHighlight-master; \
    perl Makefile.PL; \
    make test && make install

########################################################################
# Text::MarkupDiscount
########################################################################
RUN yum install -y git
RUN git clone https://github.com/rlauer6/text-markdown-discount.git; \
    cd text-markdown-discount; \
    perl Makefile.PL; \
    make && make install

########################################################################
# cleanup
########################################################################
RUN yum remove -y gcc gcc-c++ automake make

# cleanup 
RUN yum clean all && rm -rf /var/cache/yum

CMD /usr/sbin/apachectl -D FOREGROUND
