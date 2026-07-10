const express = require('express');
const app = express();
const wikip = require('wiki-infobox-parser');

app.set("view engine", 'ejs');

app.get('/', (req, res) => {
    res.render('index');
});

app.get('/index', async (req, response) => {
    let url = "https://en.wikipedia.org/w/api.php";
    let params = {
        action: "opensearch",
        search: req.query.person,
        limit: "1",
        namespace: "0",
        format: "json"
    };
    url = url + "?";
    Object.keys(params).forEach((key) => {
        url += '&' + key + '=' + params[key];
    });

    try {
        const res = await fetch(url);
        const result = await res.json();
        let x = result[3][0];
        x = x.substring(30, x.length);

        wikip(x, (err, final) => {
            if (err) {
                response.redirect('404');
            } else {
                response.send(final);
            }
        });
    } catch (err) {
        response.redirect('404');
    }
});

app.listen(3000, console.log("Listening at port 3000..."));