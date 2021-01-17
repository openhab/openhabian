export function sleep(delay) {
    var start = new Date().getTime();
    while (new Date().getTime() < start + delay);
}

// validates the reponse of a shell command. will return true if no error detected
export function validateResponse(data) {
    if (data.toLowerCase().includes("error") || data.toLowerCase().includes("failed") || data.toLowerCase().includes("please run this script as root!")) {
        return false;
    } else {
        return true;
    }
}
