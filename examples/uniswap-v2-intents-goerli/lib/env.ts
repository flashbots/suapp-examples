import dotenv from "dotenv"
import path from "path"

dotenv.config({
    path: path.resolve(import.meta.dir, "../../../.env")
})

function loadEnv() {
    let GOERLI_KEY = process.env.GOERLI_KEY
    let SUAVE_KEY = process.env.SUAVE_KEY
    // prepend 0x if var exists and 0x is not present
    if (GOERLI_KEY && !GOERLI_KEY.startsWith("0x")) {
        GOERLI_KEY = `0x${GOERLI_KEY}`
    }
    if (SUAVE_KEY && !SUAVE_KEY.startsWith("0x")) {
        SUAVE_KEY = `0x${SUAVE_KEY}`
    }
    return {
        SUAVE_KEY,
        GOERLI_KEY,
    }
}

const env = loadEnv()
export default env
