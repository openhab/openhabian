import React from "react";
import Modal from "../components/modal.jsx";
import { TextInput } from "@patternfly/react-core";
import { getInstalledopenHAB, getopenHABConsoleIP, getopenHABConsolePort, setopenHABRemoteConsole } from "../functions/openhab.js";
import ProgressDialog from "../components/progress-dialog.jsx";
import RadioBox from "../components/radio-box.jsx";
import { validateResponse } from "../functions/helpers.js";

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class OHConsole extends React.Component {
    async getDetails() {
        getInstalledopenHAB().then((data) => { this.setState({ openhab: data }) });
        var consoleip = await getopenHABConsoleIP();
        var consolePort = await getopenHABConsolePort();
        this.setState({
            consoleIP: consoleip,
            consolePort: consolePort,
            selection: (consoleip === "127.0.0.1" && consolePort == "8101") ? "local" : (consoleip === "0.0.0.0" && consolePort == "8101") ? "remote" : "custom"
        });
    }

    // starts update if all preconditions are fine
    startUpdate() {
        if (!this.validateIP(this.state.consoleIP)) {
            this.setState({ displayValidationError: "Invalid ip address!" });
            return;
        }
        if (!this.validatePort(this.state.consolePort)) {
            this.setState({ displayValidationError: "Invalid port! Only use ports between 1024 and 65532!" });
            return;
        }
        this.setState({ displayValidationError: "" });
        this.updateConfiguration();
    }

    // update console configuration
    async updateConfiguration() {
        this.setState({ showMenu: false, disableModalClose: true });
        console.log("Setting openhab console ip '" + this.state.consoleIP + "' and port '" + this.state.consolePort + "'.");
        var data = await setopenHABRemoteConsole(this.state.consoleIP, this.state.consolePort);
        if (validateResponse(data)) {
            this.configSuccesful(data);
        } else {
            this.configFailure(data);
        }
    }

    // will be called if was succesfull
    configSuccesful(data) {
        console.log("openHAB console settings updated.\n" + data);
        this.setState({
            showResult: true,
            consoleMessage: data,
            successful: true,
            disableModalClose: false,
        });
    }

    // will be called if failed
    configFailure(data) {
        var message =
      "Error could not set the openHAB console ip and port. Output: \n" +
      data;
        console.error(message);
        this.setState({
            showResult: true,
            successful: false,
            consoleMessage: message,
            disableModalClose: false,
        });
    }

    validateIP(str) {
        if (/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(str)) {
            return true;
        }
        return false;
    }

    validatePort(port) {
        var num = +port;
        return num >= 1024 && num <= 65535 && port === num.toString();
    }

    constructor() {
        super();
        this.state = {
            showMenu: true,
            show: true,
            selection: "",
            consoleIP: "",
            consolePort: "",
            successful: true,
            showResult: false,
            consoleMessage: "Update done. Please reload the page to see them.",
            disableModalClose: false,
            displayValidationError: "",
        };
        // handler for closing the modal
        this.handleClose = (e) => {
            if (!this.state.disableModalClose)
                this.props.onClose && this.props.onClose(e);
        };

        // sends ui input of console ip
        this.handleConsoleIPText = (e) => {
            this.setState({
                consoleIP: e,
                displayValidationError: "",
            });
        };
        // sends ui input of console port
        this.handleConsolePortText = (e) => {
            this.setState({
                consolePort: e,
                displayValidationError: "",
            });
        };
        // sends ui input of console presets
        this.handleSelectionChange = (e) => {
            this.setState({
                selection: e,
                consoleIP: (e === "local") ? "127.0.0.1" : (e === "remote") ? "0.0.0.0" : this.state.consoleIP
            });
        };
    }

    componentDidMount() {
        this.getDetails();
    }

    componentWillUnmount() {}

    render() {
        const showMenu = this.state.showMenu
            ? "display-block"
            : "display-none";
        const showLoading = !this.state.showMenu ? "display-block" : "display-none";
        const displayValidationError = (this.state.displayValidationError === "") ? "display-none" : "display-block";
        const showAdvanced = (this.state.selection === "custom") ? "display-block div-full-center" : "display-none";

        return (
            <Modal
        disableModalClose={this.state.disableModalClose}
        onClose={this.handleClose}
        show={this.state.show}
        header={this.state.openhab + " console settings"}
            >
                <div className={showMenu}>
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={(this.state.selection === "local")}
            value="local"
            content={
                <div>
                    <b>local</b> - Most secured option. Allows onyl local connections to the console. if you are not using the openhab console it is recomended to use this option.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={(this.state.selection === "remote")}
            value="remote"
            content={
                <div>
                    <b>remote</b> - Allows connections to the openhab console from any device. It is recomended to change the default console password when using this option.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={(this.state.selection === "custom")}
            value="custom"
            content={
                <div>
                    <b>custom</b> - <b>Advanced users!</b> Allows the configuration of the openhab console ip and port. So you can bind the console to a specific ip adress.
                </div>
            }
                    />
                    <div className={showAdvanced}>
                        <div className="display-flexflex-direction-column" style={{ marginLeft: "1rem" }}>
                            <div style={{ marginTop: "1rem" }}>
                                <label style={{ width: "50px" }}>ip:</label>
                                <TextInput
                    style={{ display: "inline-block", width: "150px" }}
                    value={this.state.consoleIP}
                    type="text"
                    id="consoleIP"
                    onChange={this.handleConsoleIPText}
                    isDisabled={this.state.selection !== "custom"}
                                />
                            </div>
                            <div style={{ marginTop: "1rem" }}>
                                <label style={{ width: "50px" }}>port:</label>
                                <TextInput
                    style={{ display: "inline-block", width: "80px" }}
                    value={this.state.consolePort}
                    type="text"
                    id="consolePort"
                    onChange={this.handleConsolePortText}
                    isDisabled={this.state.selection !== "custom"}
                                />
                            </div>
                        </div>
                        <div className={displayValidationError}>
                            <label style={{ padding: "0.5rem", color: "red" }}>
                                {this.state.displayValidationError}
                            </label>
                        </div>
                    </div>
                    <br />
                    <div className="div-full-center">
                        <button
              className="pf-c-button pf-m-primary"
              onClick={(e) => {
                  this.startUpdate();
              }}
                        >
                            Update settings
                        </button>
                    </div>
                </div>
                <div className={showLoading}>
                    <ProgressDialog
            onClose={this.handleClose}
            packageName="remote console"
            showResult={this.state.showResult}
            message={this.state.consoleMessage}
            success={this.state.successful}
            type="configure"
                    />
                </div>
            </Modal>
        );
    }
}
