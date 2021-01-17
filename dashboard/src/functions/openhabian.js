import { sendCommand } from "./cockpit.js";
import { validateResponse } from "./helpers.js";

import "core-js/stable";
import "regenerator-runtime/runtime";

export const openhabianScriptPath = "/opt/openhabian/dashboard/src/scripts";
export const openhabianPath = "/opt/openhabian";
const openhabianStub = "openhabian-stub.sh";

// call a function from openhabian
export async function callFunction(functionArray) {
    // add openhabian stub to array
    functionArray.unshift("./" + openhabianStub);
    // update config to get always the latest settings
    await updateopenHABianConfig();
    // run command
    return await sendCommand(functionArray, openhabianScriptPath);
}

// update openhabian config openhabian
export async function updateopenHABianConfig() {
    return await sendCommand(
        ["./" + openhabianStub, "update_openhabian_conf"],
        openhabianScriptPath
    );
}

// applys inprovments
export async function applyImprovments(selectedPackage) {
    await updateopenHABianConfig();
    return await sendCommand(
        ["./openhabian-apply-improvments.sh", selectedPackage],
        openhabianScriptPath
    );
}

// checks for the default system password returns true if password changed
export async function defaultSystemPasswordChanged() {
    var data = await callFunction(
        ["system_check_default_password"],
        openhabianScriptPath
    );
    if (validateResponse(data)) {
        return true;
    } else {
        return false;
    }
}

// checks for the default system password
export async function setDefaultSystemPassword(password) {
    var data = await sendCommand(
        ["./change-default-password.sh", password],
        openhabianScriptPath
    );
    return data.replace(password, "YOURPASSWORD");
}

// checks for the default system password
export async function checkopenHABianUpdates() {
    var data = await sendCommand([openhabianScriptPath + "/openhabian_check_updates.sh"], openhabianPath);
    console.log(data);
    if (data.includes("Updates available...")) {
        return true;
    }
    if (!validateResponse(data)) {
        console.error("There was an error while checking for openHABian updates. Data received:\n" + data);
    }
    return false;
}
