FROM rocker/r-ver:4.3.0

RUN apt-get update && apt-get install -y \
    default-libmysqlclient-dev \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c( \
    'shiny', \
    'ggplot2', \
    'dplyr', \
    'bslib', \
    'RMariaDB', \
    'plotly', \
    'lubridate' \
    ), repos='https://cloud.r-project.org/')"

WORKDIR /app

CMD ["Rscript", "Visu.R"]
