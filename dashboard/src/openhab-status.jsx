import React from "react";
import OHServiceDetails from "./modules/service_details.jsx";
import OHBranchSelector from "./modules/openhab_branch_selector.jsx";
import OHConsole from "./modules/openhab_console.jsx";
import { Card, CardBody, CardTitle } from "@patternfly/react-core";
import {
    getInstalledopenHAB,
    getServiceStatus,
    getopenHABVersion,
    getopenHABBranch,
    getopenHABURLs,
    getopenHABConsoleIP,
} from "./functions/openhab.js";

import "./custom.scss";
import "./patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class OHStatus extends React.Component {
    // read all openhab details
    async get_details() {
        getInstalledopenHAB().then((data) => { this.setState({ openhab: data }) });
        getServiceStatus().then((data) => { this.setState({ serviceStatus: data }) });
        getopenHABVersion().then((data) => { this.setState({ version: data }) });
        getopenHABBranch().then((data) => { this.setState({ openhabBranch: data }) });
        this.setState({
            consoleStatus:
        (await getopenHABConsoleIP()) == "127.0.0.1" ? "local" : "remote",
        });
        this.getURLs();
    }

    // refreshs the service interval. Timer will be set on component mound
    async refreshService() {
        this.setState({
            serviceStatus: await getServiceStatus(),
        });
    }

    // format the urls in  href objects
    async getURLs() {
        var urls = await getopenHABURLs();
        this.setState({
            url: (
                <div>
                    <a target="_blank" rel="noopener noreferrer" href={urls.http}>
                        {urls.http.replace("http://", "")}
                    </a>
                    <br />
                    <a target="_blank" rel="noopener noreferrer" href={urls.https}>
                        {urls.https.replace("https://", "")}
                    </a>
                </div>
            ),
        });
    }

    constructor() {
        super();
        this.state = {
            version: "-",
            openhab: "openHAB3",
            openhabBranch: "-",
            github_release_link:
        "https://github.com/openhab/openhab-distro/releases/",
            serviceStatus: "-",
            consoleStatus: "-",
            url: "-",
            showBrancheSelector: false,
            showServiceDetails: false,
            showConsoleSetings: false,
            modalContent: <div />,
        };
        // Opens the branche selector menue
        this.handleBrancheSelector = (e) => {
            if (this.state.showBrancheSelector == false) {
                this.setState({
                    showBrancheSelector: true,
                    modalContent: (<OHBranchSelector onClose={this.handleBrancheSelector} />),
                });
            } else {
                this.setState({
                    showBrancheSelector: false,
                    modalContent: <div />,
                });
                this.get_details();
            }
        };

        // Opens the service status details
        this.handleServiceDetails = (e) => {
            if (this.state.showServiceDetails == false) {
                this.setState({
                    showServiceDetails: true,
                    modalContent: (
                        <OHServiceDetails
              onClose={this.handleServiceDetails}
                        />
                    ),
                });
            } else {
                this.setState({
                    showServiceDetails: false,
                    modalContent: <div />,
                });
            }
        };

        // Opens the service status details
        this.handleConsoleSettings = (e) => {
            if (this.state.showConsoleSetings == false) {
                this.setState({
                    showConsoleSetings: true,
                    modalContent: (
                        <OHConsole
              onClose={this.handleConsoleSettings}
                        />
                    ),
                });
            } else {
                this.setState({
                    showConsoleSetings: false,
                    modalContent: <div />,
                });
                this.get_details();
            }
        };

    /* Modal action handler end */
    }

    /* Runs when component is build */
    componentDidMount() {
        this.get_details();
        this.interval = setInterval(() => this.refreshService(), 15000);
    }

    // runs when component will be unmount
    componentWillUnmount() {
        clearInterval(this.interval);
    }

    render() {
        return (
            <Card className="system-configuration">
                <CardTitle style={{ paddingLeft: "16px" }}>
                    {this.state.openhab} status
                </CardTitle>
                <CardBody>
                    <div>{this.state.modalContent}</div>
                    <table className="pf-c-table pf-m-grid-md pf-m-compact">
                        <tbody>
                            <tr>
                                <th scope="row">Version: </th>
                                <td>
                                    <a
                    target="_blank"
                    rel="noopener noreferrer"
                    href={this.state.github_release_link}
                                    >
                                        {this.state.version}
                                    </a>
                                </td>
                            </tr>
                            <tr>
                                <th scope="row">Branch: </th>
                                <td>
                                    <a
                    onClick={(e) => {
                        this.handleBrancheSelector();
                    }}
                                    >
                                        {this.state.openhabBranch}
                                    </a>
                                </td>
                            </tr>
                            <tr>
                                <th scope="row">Service: </th>
                                <td>
                                    <a
                    onClick={(e) => {
                        this.handleServiceDetails();
                    }}
                                    >
                                        {this.state.serviceStatus}
                                    </a>
                                </td>
                            </tr>
                            <tr>
                                <th scope="row">Console: </th>
                                <td>
                                    <a
                    onClick={(e) => {
                        this.handleConsoleSettings();
                    }}
                                    >
                                        {this.state.consoleStatus}
                                    </a>
                                </td>
                            </tr>
                            <tr>
                                <th style={{ paddingRight: "-2rem" }} scope="row">
                                    URLs:{" "}
                                </th>
                                <td>{this.state.url}</td>
                            </tr>
                        </tbody>
                    </table>
                </CardBody>
            </Card>
        );
    }
}
