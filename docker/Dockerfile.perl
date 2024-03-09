########################################################################
# BASE PERL APPLICATION IMAGE
########################################################################
FROM amazonlinux:2

RUN amazon-linux-extras install epel -y

########################################################################
# base dependencies
########################################################################
COPY packages .
RUN yum install -y $(cat packages)

# cpanm
RUN curl -L https://cpanmin.us | perl - App::cpanminus

# Perl dependencies
COPY requires.base .
RUN for a in $(cat requires.base | grep -v '^#'); do \
      cpanm -n -v $a || false; \
    done

# Perl dependencies - extras
COPY requires.extras .d
RUN for a in $(cat requires.extras | grep -v '^#'); do \
      cpanm -n -v $a || false; \
    done

