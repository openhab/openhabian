import React from "react";
import LogViewer from "./modules/logviewer.jsx";
import OpenHABianApplyImprovements from "./modules/openhabian_apply_improvements.jsx";
import OHBackupRestore from "./modules/openhab_backup_restore.jsx";
import { Card, CardBody, CardTitle } from "@patternfly/react-core";

import "./custom.scss";
import "./patternfly.scss";

export default class Tools extends React.Component {
    constructor() {
        super();
        this.state = {
            showLogViewer: false,
            showApplyImprovements: false,
            showBackupRestore: false,
            modalContent: <div />,
        };
        // handles the modal dialog of the logviewer
        this.handleLogViewer = (e) => {
            if (this.state.showLogViewer == false) {
                this.setState({ showLogViewer: true, modalContent: <LogViewer onClose={this.handleLogViewer} /> });
            } else {
                this.setState({ showLogViewer: false, modalContent: <div /> });
            }
        };
        // handles the modal dialog of improvments section
        this.handleImprovements = (e) => {
            if (this.state.showApplyImprovements == false) {
                this.setState({ showApplyImprovements: true, modalContent: <OpenHABianApplyImprovements onClose={this.handleImprovements} /> });
            } else {
                this.setState({ showApplyImprovements: false, modalContent: <div /> });
            }
        };
        // handles the modal dialog of backup and restore section
        this.handleBackupRestore = (e) => {
            if (this.state.showBackupRestore == false) {
                this.setState({ showBackupRestore: true, modalContent: <OHBackupRestore onClose={this.handleBackupRestore} /> });
            } else {
                this.setState({ showBackupRestore: false, modalContent: <div /> });
            }
        };
    }

    /* Runs when component is build */
    componentDidMount() {
    }

    componentWillUnmount() {
    }

    render() {
        return (
            <Card className="system-configuration">
                <CardTitle>Tools</CardTitle>
                <CardBody>
                    <div>{this.state.modalContent}</div>
                    <table className="pf-c-table pf-m-grid-md pf-m-compact">
                        <tbody>
                            <tr>
                                <td>
                                    <a
                     onClick={(e) => {
                         this.handleLogViewer();
                     }}
                                    >
                                        LogViewer
                                    </a>
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    <a
                     onClick={(e) => {
                         this.handleImprovements();
                     }}
                                    >
                                        Apply Improvements
                                    </a>
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    <a
                     onClick={(e) => {
                         this.handleBackupRestore();
                     }}
                                    >
                                        Backup & Restore
                                    </a>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </CardBody>
            </Card>
        );
    }
}
