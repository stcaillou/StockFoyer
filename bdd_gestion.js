const mysql = require('mysql2/promise');

const dbConfig = {
    host: 'mysql',
    user: 'app_user',
    password: 'app_password',
    database: 'app_db',
    port: 3306,
};


async function getStockList(as_like) {
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);
        if (as_like != "") {
            const [rows] = await connection.query('SELECT stock.code_article, designation, quantite, nom_tpe, type, debit_factor, sup, inf FROM stock LEFT JOIN tpe_code_article ON tpe_code_article.code_article=stock.code_article LEFT JOIN limites ON limites.code_article = stock.code_article WHERE nom_tpe LIKE "%' + as_like + '%" OR designation LIKE "%' + as_like + '%" ');
            return rows;

        }
        else {
            const [rows] = await connection.query('SELECT stock.code_article, designation, quantite, nom_tpe, type, debit_factor, sup, inf FROM stock LEFT JOIN tpe_code_article ON tpe_code_article.code_article=stock.code_article LEFT JOIN limites ON limites.code_article = stock.code_article');
            return rows;
        }
    } catch (error) {
        console.error('Erreur dans getStockList :', error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}

async function debitStock(code_article) {
    let connection;

    try {
        connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.execute(
            'SELECT debit_factor FROM tpe_code_article WHERE code_article = ?',
            [code_article]
        );

        let debit = 1;

        if (rows.length > 0 && rows[0].debit_factor) {
            debit = rows[0].debit_factor;
        }
        await connection.execute(
            'UPDATE stock SET quantite = quantite - ? WHERE code_article = ?',
            [debit, code_article]
        );

        addLogs(`Débit d'un item : ${code_article} (-${debit})`);
    }
    catch (error) {
        console.error(error);
        console.error("Erreur");
    }
    finally {
        if (connection) {
            await connection.end();
        }
    }
}

async function bindItem(code_article, nom_tpe, type, debit_factor) {
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);

        const [existingRows] = await connection.query(
            'SELECT * FROM tpe_code_article WHERE code_article = ?',
            [code_article]
        );

        if (existingRows.length > 0) {
            await connection.query(
                `UPDATE tpe_code_article
                 SET nom_tpe = ?, type = ?, debit_factor = ?
                 WHERE code_article = ?`,
                [nom_tpe, type || null, debit_factor || null, code_article]
            );
            addLogs(`Mise à jour du bind (${code_article}, ${nom_tpe})`);
        } else {
            await connection.query(
                `INSERT INTO tpe_code_article
                 (code_article, nom_tpe, type, debit_factor)
                 VALUES (?, ?, ?, ?)`,
                [code_article, nom_tpe, type || null, debit_factor || null]
            );
            addLogs(`Ajout d'un bind (${code_article}, ${nom_tpe})`);
        }
    } catch (error) {
        console.error("Erreur lors du bind :", error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}

async function addLogs(info) {
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.query('INSERT INTO logs (detail) VALUES ("' + info + '")');
    } catch (error) {
        console.error('Erreur dans getStockList :', error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}


async function addFacture(name, path) {
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.query('INSERT INTO factures (name, path) VALUES ("' + name + '", "' + path + '")');
    } catch (error) {
        console.error('Erreur dans getStockList :', error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}

async function getFactures() {
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.query('SELECT * FROM factures');
        return rows;
    } catch (error) {
        console.error('Erreur dans getStockList :', error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}


async function updateStock() {
    let connection;

    try {
        connection = await mysql.createConnection(dbConfig);

        await connection.beginTransaction();


        await connection.execute(`
            UPDATE stock s
            JOIN (
                SELECT 
                    tca.code_article,
                    COUNT(*) AS nb_ventes,
                    COALESCE(tca.debit_factor, 1) AS debit_factor
                FROM historique_vente hv
                JOIN tpe_code_article tca 
                    ON hv.nom_tpe = tca.nom_tpe
                WHERE hv.status = 0
                GROUP BY tca.code_article
            ) ventes
                ON s.code_article = ventes.code_article
            SET s.quantite = s.quantite - (
                ventes.nb_ventes * ventes.debit_factor
            )
        `);

        await connection.execute(`
            UPDATE historique_vente hv
            JOIN tpe_code_article tca 
                ON hv.nom_tpe = tca.nom_tpe
            JOIN stock s
                ON s.code_article = tca.code_article
            SET hv.status = 1
            WHERE hv.status = 0
        `);

        await connection.commit();

        console.log('Stock mis à jour avec succès');

    } catch (error) {

        if (connection) {
            await connection.rollback();
        }

        console.error('Erreur dans updateStock :', error);
        throw error;

    } finally {

        if (connection) {
            await connection.end();
        }
    }
}


async function updateItem(code_article, nom_tpe, quantite, type, debit_factor, sup, inf) {
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);
        await connection.query('UPDATE stock SET quantite=' + quantite + ' WHERE code_article=' + code_article);
        await bindItem(code_article, nom_tpe, type, debit_factor);
        await setLimites(code_article, sup, inf);
    } catch (error) {
        console.error('Erreur dans getStockList :', error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}


async function setCustomItem(designation) {
    let conenction;
    try{
        connection = await mysql.createConnection(dbConfig);
        const [code_article] = await connection.query('SELECT code_article FROM stock WHERE code_article <= 0 ORDER BY code_article DESC LIMIT 1');
        if(code_article.length > 0){
            new_code = code_article[0]["code_article"] - 1
            await connection.query('INSERT INTO stock (code_article, designation) VALUES ("'+new_code+'", "'+designation+'")' );
        }
        else{
            await connection.query('INSERT INTO stock (code_article, designation) VALUES ("-1", "'+designation+'")' );
        }

    } catch(error){
        console.log("Erreur lors de l'ajout de l'item custom", error);
        throw error;
    } finally {
        if(connection) await connection.end();
    }

}

async function setLimites(code_article, sup, inf){
    let connection;
    try {
        connection = await mysql.createConnection(dbConfig);

        const [existingRows] = await connection.query(
            'SELECT * FROM limites WHERE code_article = ?',
            [code_article]
        );

        if (existingRows.length > 0) {
            await connection.query(
                `UPDATE limites
                 SET sup = ?, inf = ?
                 WHERE code_article = ?`,
                [sup || null, inf || null, code_article]
            );
            addLogs(`Mise à jour d'une limite (${code_article})`);
        } else {
            await connection.query(
                `INSERT INTO limites
                 (code_article, sup, inf)
                 VALUES (?, ?, ?)`,
                [code_article, sup || null, inf || null]
            );
            addLogs(`Ajout d'une limite (${code_article})`);
        }
    } catch (error) {
        console.error("Erreur lors de l'ajout de la limites :", error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }
}

module.exports = {
    getStockList, debitStock, bindItem, addFacture, getFactures, updateItem, updateStock, setCustomItem
};