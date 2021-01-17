import cockpit from "cockpit";

import "core-js/stable";
import "regenerator-runtime/runtime";

// returns the users home directory
export async function getUserDetails() {
    // get the user
    return await cockpit.user().then((user) => {
        return user;
    });
}

// reads a file on server async to get immediate result
export async function readFile(filePath) {
    return await cockpit
            .file(filePath, {
                superuser: "require",
                err: "out",
            })
            .read()
            .then((data) => {
                return data;
            })
            .catch((exception, data) => {
                console.error(
                    "Could not read the file '" + filePath + "'. Exception: \n" + exception
                );
            });
}

// replace a file on server with a given string
export async function replaceFile(filePath, newContent) {
    return await cockpit
            .file(filePath, {
                superuser: "require",
                err: "out",
            })
            .replace(newContent)
            .then((data) => {
                return data;
            })
            .catch((exception, data) => {
                var msg = "Could not replace the file '" + filePath + "'. Exception: \n" + exception;
                console.error(msg);
                return msg;
            });
}

// get a bynary file on server async to get immediate result
export async function getBinaryFile(filePath) {
    return await cockpit
            .file(filePath, {
                superuser: "require",
                err: "out",
                binary: true,
            })
            .read()
            .then((data) => {
                return data;
            })
            .catch((exception, data) => {
                console.error(
                    "Could not get the binary file '" + filePath + "'. Exception: \n" + exception
                );
            });
}

// download a file to the client
// get a bynary file on server async to get immediate result
export async function downloadFile(filePath, fileName, mimeType) {
    var byte = await (getBinaryFile(filePath));
    var blob = new Blob([byte], { type: mimeType });
    var link = document.createElement('a');
    link.href = window.URL.createObjectURL(blob);
    link.download = fileName;
    link.click();
}

// run command on server with result
export async function sendCommand(commandArray, directory) {
    // set default directory if not provided to function
    if (directory === undefined || directory === "") {
        directory = (await getUserDetails()).home;
    }
    return await cockpit
            .spawn(commandArray, {
                superuser: "require",
                err: "out",
                directory: directory,
            })
            .then((data) => {
                return data;
            })
            .catch((exception, data) => {
                var msg = "Error while sending the command '" + commandArray.toString() + "' in directroy '" + directory + "'. Exception: \n" +
          exception + "\n\nConsole-Output: \n " + data;
                console.error(msg);
                return msg;
            });
}

// run command on server with result
export async function sendScript(script, args, directory) {
    // set default directory if not provided to function
    if (directory === undefined || directory === "") {
        directory = (await getUserDetails()).home;
    }
    return await cockpit
            .script(script, args, {
                superuser: "require",
                err: "out",
                directory: directory,
            })
            .then((data) => {
                return data;
            })
            .catch((exception, data) => {
                var msg = "Error while sending the following script in directory '" + directory + "'. Script:\n'" + script + "' \n\n Exception: \n" +
                exception + "\n\nConsole-Output: \n " + data;
                console.error(msg);
                return msg;
            });
}
