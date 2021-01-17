import React from "react";
import Modal from "../components/modal.jsx";
import ActionGroup from "../components/action-group.jsx";
import { downloadFile } from "../functions/cockpit.js";
import {
    getInstalledopenHAB,
    getopenHABBackups,
    backupopenHAB,
    restoreopenHABBackup,
    deleteopenHABBackup,
    getopenHABBackupDir,
} from "../functions/openhab.js";
import ProgressDialog from "../components/progress-dialog.jsx";
import NotificationDialog from "../components/notification-dialog.jsx";
import { DropdownItem } from "@patternfly/react-core";
import { validateResponse } from "../functions/helpers.js";

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class OHBackupRestore extends React.Component {
    getDetails() {
        getInstalledopenHAB().then((data) => {
            this.setState({ openhab: data });
        });
        this.buildTable();
    }

    // builds the table with all backups
    async buildTable() {
        var backups = await getopenHABBackups();
        if (backups !== undefined) {
            this.loadTable(backups);
        } else {
            this.setState({ tableContent: <label>No backups available</label> });
        }
    }

    // create the table structure
    loadTable(backups) {
        var result = [];
        backups.forEach((backup) => {
            result.push(
                <tr key={backup.name} className="table-row">
                    <td>{backup.date.toLocaleString()}</td>
                    <td>{backup.size}</td>
                    <td>{this.getActionItemGroup(backup.name)}</td>
                </tr>
            );
        });
        this.setState({ backupTable: result });
    }

    // returns an action item object for this row
    getActionItemGroup(name) {
        return (
            <ActionGroup
        position="right"
        dropdownItems={[
            <DropdownItem
            key="delete"
            onClick={(e) => {
                this.handleDelete(name);
            }}
            >
                Delete
            </DropdownItem>,
            <DropdownItem
            key="download"
            onClick={(e) => {
                this.handleDownload(name);
            }}
            >
                Download
            </DropdownItem>,
            <DropdownItem
            key="restore"
            onClick={(e) => {
                this.handleRestore(name);
            }}
            >
                Restore
            </DropdownItem>,
        ]}
            />
        );
    }

    // opens confirmation sialog for backup
    async createBackup() {
        this.setState({
            disableModalClose: true,
            notificationDialog: (
                <NotificationDialog
          onConfirm={this.handleBackup}
          onCancel={this.handleCancel}
          type="info"
          message={
              "This will create a backup of your openHAB configuration using openHAB's builtin backup tool. The backup will be created in '" +
            (await getopenHABBackupDir()) +
            "'."
          }
                />
            ),
        });
    }

    // creates a backup
    async runBackupProcess() {
        this.setState({
            notificationDialog: <div />,
            type: "backup",
            showMenu: false,
            disableModalClose: true,
        });
        var data = await backupopenHAB();
        if (validateResponse(data)) {
            this.configSuccesful(data);
        } else {
            this.configFailure(data);
        }
        this.buildTable();
    }

    // ask user for confirmation for backup restore
    restoreBackup(name) {
        this.setState({
            disableModalClose: true,
            notificationDialog: (
                <NotificationDialog
          onConfirm={this.handleRestoreBackup}
          value={name}
          onCancel={this.handleCancel}
          type="warning"
          message={
              "This will overwrite your current configuration with the following backup '" + name + "'. Are you sure?"
          }
                />
            ),
        });
    }

    // restores a backup
    async runRestoreBackup(name) {
        this.setState({
            type: "restore",
            showMenu: false,
            disableModalClose: true,
            notificationDialog: <div />
        });
        var data = await restoreopenHABBackup(name);
        if (validateResponse(data)) {
            this.configSuccesful(data);
        } else {
            this.configFailure(data);
        }
    }

    // Asks if backup should be removed
    deleteBackup(name) {
        this.setState({
            disableModalClose: true,
            notificationDialog: (
                <NotificationDialog
          onConfirm={this.handleBackupDelete}
          value={name}
          onCancel={this.handleCancel}
          type="warning"
          message={
              "This will delete the backup '" + name + "' from you system. Are you sure?"
          }
                />
            ),
        });
    }

    // Removes backup from system
    async runBackupDelete(name) {
        this.closeNotificationDialog();
        console.log("deleting openHAB backup '" + name + "'.");
        await deleteopenHABBackup(name);
        this.buildTable();
    }

    // will be called if was succesfull
    configSuccesful(data) {
        console.log("openHAB " + this.state.type + " succesful.\n" + data);
        this.setState({
            showResult: true,
            consoleMessage: data,
            successful: true,
            disableModalClose: false,
        });
    }

    // will be called if failed
    configFailure(data) {
        var message = "Error could not restore openHAB backup. Output: \n" + data;
        console.error(message);
        this.setState({
            showResult: true,
            successful: false,
            consoleMessage: message,
            disableModalClose: false,
        });
    }

    // closes the notification dialog and allows closing the modal again
    closeNotificationDialog() {
        this.setState({ notificationDialog: <div /> });
        setTimeout(
            function() {
                this.setState({ disableModalClose: false });
            }
                    .bind(this),
            100
        );
    }

    // Doownload an existing backup
    async downloadBackup(name) {
        downloadFile(await getopenHABBackupDir() + "/" + name, name, "application/zip");
    }

    constructor(props) {
        super(props);
        this.state = {
            backupTable: <tr />,
            showMenu: true,
            show: true,
            successful: true,
            showResult: false,
            consoleMessage: "Update done. Please reload the page to see them.",
            disableModalClose: false,
            isOpen: false,
            type: "backup",
            notificationDialog: <div />,
        };
        // handler for closing the modal
        this.handleClose = (e) => {
            if (!this.state.disableModalClose)
                this.props.onClose && this.props.onClose(e);
        };
        // will be called by action button
        this.handleDownload = (e) => {
            this.downloadBackup(e);
        };
        // will be called by action button
        this.handleDelete = (e) => {
            this.deleteBackup(e);
        };
        // will be called by action button
        this.handleRestore = (e) => {
            this.restoreBackup(e);
        };
        // will be called from the confirmation dialog
        this.handleBackup = (e) => {
            this.runBackupProcess();
        };
        // will be called from the confirmation dialog
        this.handleRestoreBackup = (e) => {
            this.runRestoreBackup(e);
        };
        // will be called from the confirmation dialog
        this.handleBackupDelete = (e) => {
            this.runBackupDelete(e);
        };
        // will be called from the confirmation dialog
        this.handleCancel = (e) => {
            this.closeNotificationDialog();
        };
    }

    componentDidMount() {
        this.getDetails();
    }

    componentWillUnmount() {}

    render() {
        const showMenu = this.state.showMenu ? "display-block" : "display-none";
        const showLoading = !this.state.showMenu ? "display-block" : "display-none";

        return (
            <Modal
        disableModalClose={this.state.disableModalClose}
        onClose={this.handleClose}
        show={this.state.show}
        header={this.state.openhab + " backup & restore"}
            >
                {this.state.notificationDialog}
                <div className={showMenu}>
                    <h4>Available backups</h4>
                    <table className="pf-c-table pf-m-grid-md pf-m-compact table">
                        <thead className="table-head">
                            <tr>
                                <th scope="col">
                                    <b>Date/Time</b>
                                </th>
                                <th scope="col">
                                    <b>Size</b>
                                </th>
                                <th scope="col">
                                    <b>Actions</b>
                                </th>
                            </tr>
                        </thead>
                        <tbody className="table-body">{this.state.backupTable}</tbody>
                    </table>
                    <br />
                    <div className="div-full-center">
                        <button
              className="pf-c-button pf-m-primary"
              onClick={(e) => {
                  this.createBackup();
              }}
                        >
                            Create new backup
                        </button>
                    </div>
                </div>
                <div className={showLoading}>
                    <ProgressDialog
            onClose={this.handleClose}
            packageName="openHAB config"
            showResult={this.state.showResult}
            message={this.state.consoleMessage}
            success={this.state.successful}
            type={this.state.type}
                    />
                </div>
            </Modal>
        );
    }
}
