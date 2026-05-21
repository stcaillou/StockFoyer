const express = require('express');
const path = require('path');
const app = express();
const { exec } = require('child_process');
const port = 3000;

const http = require('http');
const server = http.createServer(app);
const { Server } = require('socket.io');
const io = new Server(server);

const fileUpload = require("express-fileupload");

const bdd_gestion = require('./bdd_gestion.js'); 

app.use(express.static(path.join(__dirname, 'public')));

app.use('/app/uploads', express.static(path.join(__dirname, 'uploads')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.use(fileUpload({
    limits: {
        fileSize: 50 * 1024 * 1024 // 50MB
    },
    abortOnLimit: true,
    responseOnLimit: "Fichier trop volumineux"
}));


const pythonPath = "python3";

const fs = require("fs");

/*API pour le DEBIT 
app.post("/debit", async function(req, res) {

    try {
        // Récupération du JSON envoyé
        const { code_article } = req.body;

        if (!code_article) {
            return res.status(400).json({
                success: false,
                message: "code_article manquant"
            });
        }

        await bdd_gestion.debitStock(code_article);

        res.json({
            success: true,
            message: "Stock débité"
        });

    } catch (error) {

        console.error(error);

        res.status(500).json({
            success: false,
            message: "Erreur serveur"
        });
    }
});*/


app.post("/uploadventes", function(req, res) {
    if (req.files && Object.keys(req.files).length !== 0) {

        const uploadedFile = req.files.uploadFile;
        const uploadPath = __dirname + "/uploads/Historiques/" + uploadedFile.name;

        uploadedFile.mv(uploadPath, function (err) {
            if(err) {
                console.log(err);
                res.send("Echec du chargement du fichier");
            }
            else 
            {
                console.log("Traitement du fichier de l'historique")
                const command = `"${pythonPath}" "${path.join(__dirname, 'data_process.py')}" --file "${uploadPath}"`;
                exec(command, (error, stdout, stderr) => {
                    
                    if (error) {
                        console.error("❌ Erreur lors de l'exécution du script Python :", error);
                        return res.status(500).send(`Erreur : ${error.message}`);
                    }
                    if (stderr) {
                        console.error("❌ Erreur Python (stderr) :", stderr);
                        return res.status(500).send(`Erreur Python : <pre>${stderr}</pre>`);
                    }
                    else{
                        fs.unlink(uploadPath, () => {});
                        res.redirect("/")
                    }
                })
            }
        })
    
    }else res.send("Aucun fichier chargé");
})


app.post("/uploadfacture", function (req, res) {

  if (req.files && Object.keys(req.files).length !== 0) {

    const uploadedFile = req.files.uploadFile;
    const uploadPath = __dirname + "/uploads/Factures/" + uploadedFile.name;

    if (fs.existsSync(uploadPath)) {
      return res.status(400).send("Cette facture existe déjà.");
    }

    uploadedFile.mv(uploadPath, function (err) {
      if (err) {
        console.log(err);
        return res.send("Echec du chargement du fichier");
      }

      const command = `"${pythonPath}" "${path.join(__dirname, 'main.py')}" --file "${uploadPath}"`;

      exec(command, (error, stdout, stderr) => {

        if (error) {
          console.error("❌ Erreur lors de l'exécution du script Python :", error);
          return res.status(500).send(`Erreur : ${error.message}`);
        }

        if (stderr) {
          console.error("❌ Erreur Python (stderr) :", stderr);
          return res.status(500).send(`Erreur Python : <pre>${stderr}</pre>`);
        }

        bdd_gestion.addFacture(uploadedFile.name, uploadPath);
        return res.redirect("/");
      });
    });

  } else {
    res.send("Aucun fichier chargé");
  }
});

io.on('connection', (socket) => {

    socket.on('stock_list', async (data) => {
        try {
            const stockList = await bdd_gestion.getStockList(data["as_like"]);
            io.emit('stock_list_response', stockList);
        } catch (error) {
            console.error('Erreur lors de la récupération des stocks :', error);
            socket.emit('stock_list_error', { error: 'Impossible de récupérer la liste des stocks.' });
        }
    });

    socket.on('facture_list', async (data) => {
        const factureList = await bdd_gestion.getFactures();
        io.emit('facture_list', factureList);
    })

    /*socket.on('bind_item', async (data) => {
        await bdd_gestion.bindItem(data["code_article"], data["nom_tpe"])
        const stockList = await bdd_gestion.getStockList(""); 
        io.emit('stock_list_response', stockList);
    })*/ 

    socket.on('debit_item', async (data) => {
        await bdd_gestion.debitStock(data["code_article"]);
        const stockList = await bdd_gestion.getStockList("");
        io.emit('stock_list_response', stockList);
    })

    
    socket.on('update_item', async (data) => {
        console.log(data);
        await bdd_gestion.updateItem(data.code_article, data.nom_tpe,  data.quantite, data.type, data.debit_factor, data.sup, data.inf)
        const stockList = await bdd_gestion.getStockList("");
        io.emit('stock_list_response', stockList);
    })

    socket.on("add_custom_item", async(data) => {
        await bdd_gestion.setCustomItem(data.designation)
        const stockList = await bdd_gestion.getStockList("");
        io.emit('stock_list_response', stockList);
    })

    socket.on("manuel_update_stock", async(data) => {
        io.emit("message")
        await bdd_gestion.updateStock()
        const stockList = await bdd_gestion.getStockList("");
        io.emit('stock_list_response', stockList);
    })

    socket.on('disconnect', () => {
    });
});


server.listen(port, () => {
    console.log(`Serveur démarré sur http://localhost:${port}`);
});