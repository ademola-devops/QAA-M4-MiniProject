'use strict'

const header = document.querySelector('h1');

fetch('/colour').then((response) => {
    response.text().then((data) => {
        header.style.color = data;
    })
})
