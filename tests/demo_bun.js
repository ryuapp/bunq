const file = Bun.file("README.md");

console.log(await file.text());
console.log(await file.exists());
