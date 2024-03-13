# uniswap-v2-intents-goerli

To install dependencies:

```bash
bun install
```

Setup .env:

```bash
# assuming you're in this directory, go to project root
cd ../..
cp .env.example .env

# populate GOERLI_KEY and SUAVE_KEY in .env
vim .env
```

To run:

```bash
bun run index.ts
```

To deploy new contracts and run:

```bash
DEPLOY=true bun run index.ts
```

This project was created using `bun init` in bun v1.0.23. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.
