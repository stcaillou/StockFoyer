FROM node:18

# Installer Python + pip
RUN apt-get update && apt-get install -y python3 python3-pip

# Installer dépendance MySQL pour Python
RUN pip3 install mysql-connector-python pdfminer.six pandas --break-system-packages

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

CMD ["npx", "nodemon", "server.js"]