import React from "react";
import cockpit from "cockpit";
import Dropdown from "../components/dropdown.jsx";
import Modal from "../components/modal.jsx";
import { getopenHABServiceName, sendServiceCommand, getInstalledopenHAB } from "../functions/openhab.js";

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class OHServiceDetails extends React.Component {
    getDetails() {
        getInstalledopenHAB().then((data) => { this.setState({ openhab: data }) });
    }

    async refreshService() {
        var proc = cockpit.spawn(["systemctl", "status", (await getopenHABServiceName())]);
        proc.stream((data) => {
            this.setState({ message: data });
        });
    }

    constructor() {
        super();
        this.state = {
            show: true,
            openhab: "",
            message: "-",
            showDropdown: false,
            disableModalClose: false,
        };
        // handler for closing the modal
        this.handleClose = (e) => {
            if (!this.state.disableModalClose)
                this.props.onClose && this.props.onClose(e);
        };
        // handles the dropdown selection
        this.handleDropdown = (e) => {
            this.setState({
                showDropdown: !this.state.showDropdown,
            });
        };
        // handles send command to control service
        this.handleServiceCommand = (command) => {
            this.setState({
                showDropdown: false,
            });
            sendServiceCommand(command);
        };
    }

    /* Runs when component is build */
    componentDidMount() {
        this.getDetails();
        this.refreshService();
        this.interval = setInterval(() => this.refreshService(), 3000);
    }

    componentWillUnmount() {
        clearInterval(this.interval);
    }

    render() {
        return (
            <Modal
        disableModalClose={this.state.disableModalClose}
        onClose={this.handleClose}
        show={this.state.show}
        header={this.state.openhab + " service status"}
            >
                <div className="display-flex-justify-space-between">
                    <h4>Status: </h4>
                    <div className="display-flex">
                        <Dropdown
              label="Restart"
              value="restart"
              onSelect={this.handleServiceCommand}
                        >
                            <li>
                                <button
                  onClick={(e) => {
                      this.handleServiceCommand("start");
                  }}
                  className="dropdown-item pf-c-button"
                  type="button"
                                >
                                    Start
                                </button>
                            </li>
                            <li>
                                <button
                  onClick={(e) => {
                      this.handleServiceCommand("stop");
                  }}
                  className="dropdown-item pf-c-button"
                  type="button"
                                >
                                    Stop
                                </button>
                            </li>
                            <li>
                                <button
                  onClick={(e) => {
                      this.handleServiceCommand("restart");
                  }}
                  className="dropdown-item pf-c-button"
                  type="button"
                                >
                                    Restart
                                </button>
                            </li>
                        </Dropdown>
                    </div>
                </div>
                <div className="padding-top">
                    <p className="console-text">{this.state.message}</p>
                </div>
            </Modal>
        );
    }
}
