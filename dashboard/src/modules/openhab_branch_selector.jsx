import React from "react";
import RadioBox from "../components/radio-box.jsx";
import Modal from "../components/modal.jsx";
import ProgressDialog from "../components/progress-dialog.jsx";
import { getInstalledopenHAB, getopenHABBranch, installopenHAB } from "../functions/openhab.js";
import { validateResponse } from "../functions/helpers.js";
import NotificationDialog from "../components/notification-dialog.jsx";

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class OHBranchSelector extends React.Component {
    // load details for this component
    getDetails() {
        getInstalledopenHAB().then((data) => { this.setState({ openhab: data }) });
        getopenHABBranch().then((data) => { this.setState({ branch: data }); this.setCurrentBranch(data) });
    }

    // Reset displayed items
    setCurrentBranch(branch) {
        this.resetSelection();
        if (branch === "release") this.setState({ branchRelease: true });
        if (branch === "testing") this.setState({ branchTesting: true });
        if (branch === "snapshot")
            this.setState({ branchSnapshot: true });
    }

    // Resets the radio checkbox on nes selection
    resetSelection() {
        this.setState({
            branchRelease: false,
            branchTesting: false,
            branchSnapshot: false,
        });
    }

    // Start the installation with update button. Selects the defined branche
    updateBranche() {
        // check for valid oh version to avoid unexpected downgrade
        if (this.state.openhab !== "openHAB3" && this.state.openhab !== "openHAB2") {
            console.error("Error openHAB version was not properly detected. Can not run the branch update");
            return;
        }
        if (this.state.branchRelease === true) {
            this.showConfirmationMessage("stable", "release");
        }
        if (this.state.branchTesting === true) {
            this.showConfirmationMessage("testing", "testing");
        }
        if (this.state.branchSnapshot === true) {
            this.showConfirmationMessage("unstable", "snapshot");
        }
    }

    showConfirmationMessage(branch, displayName) {
        this.setState({
            disableModalClose: true,
            notificationDialog: (
                <NotificationDialog
          onConfirm={this.handleConfirmation}
          value={branch + "/" + displayName}
          onCancel={this.handleCancel}
          type="info"
          message={this.getConfirmationMessage(branch)}
                />
            ),
        });
    }

    // get confirmation meesage to show user
    getConfirmationMessage(branch) {
        if (branch === "stable") {
            return "You are about to install or change to the latest stable openHAB3 release. \n\nPlease be aware that downgrading from a newer unstable snapshot build is not officially supported. Please consult with the documentation or community forum and be sure to take a full openHAB configuration backup first!";
        }
        if (branch === "testing") {
            return "You are about to install or change to the latest milestone (testing) \n\nopenHAB3 build. It contains the latest features and is supposed to run stable, but if you experience bugs or incompatibilities, please help with enhancing openHAB by posting them on the community forum or by raising a GitHub issue.\n\nPlease be aware that downgrading from a newer build is not officially supported.";
        }
        if (branch === "unstable") {
            return "Proceed with caution!\n\nYou are about to switch over to the latest openHAB3 unstable snapshot build. The daily snapshot builds contain the latest features and improvements but might also suffer from bugs or incompatibilities. Please be sure to take a full openHAB configuration backup first!";
        }
    }

    // Installs openhab
    async installScript(value) {
        var branch = value.split("/")[0];
        var displayName = value.split("/")[1];
        this.setState({ showMenu: false, disableModalClose: true, brancheToInstall: displayName, notificationDialog: <div /> });
        console.log("Installation of '" + this.state.openhab + "' branch '" + displayName + "' started.");
        var data = await installopenHAB(this.state.openhab, branch);
        if (validateResponse(data)) {
            this.installSuccesful(data);
        } else {
            this.installFailure(data);
        }
    }

    // will be called if installation was succesfull
    installSuccesful(data) {
        console.log("installation of '" + this.state.openhab + "' branch '" + this.state.brancheToInstall + "' done. Output: \n" + data);
        this.setState({
            consoleMessage: data,
            disableModalClose: false,
            showResult: true,
            successful: !(data.toLowerCase().includes("error") || data.toLowerCase().includes("failed")),
        });
    }

    // will be called if installation failed
    installFailure(data) {
        var msg = "Error while installing " + this.state.openhab + " from branch (" + this.state.brancheToInstall + "). Output: \n" + data;
        console.error(msg);
        this.setState({
            successful: false,
            disableModalClose: false,
            showResult: true,
            consoleMessage: msg
        });
    }

    constructor() {
        super();
        this.state = {
            show: true,
            branchRelease: false,
            branchTesting: false,
            branchSnapshot: false,
            brancheToInstall: "",
            showMenu: true,
            showResult: false,
            successful: false,
            consoleMessage: "",
            disableModalClose: false,
            notificationDialog: <div />
        };

        // handler for closing the modal
        this.handleClose = (e) => {
            if (!this.state.disableModalClose)
                this.props.onClose && this.props.onClose(e);
        };

        // Sets the repo to be used
        this.handleSelectionChange = (e) => {
            this.resetSelection();
            if (e === "release")
                this.setState({ branchRelease: true });
            if (e === "testing")
                this.setState({ branchTesting: true });
            if (e === "snapshot")
                this.setState({ branchSnapshot: true });
        };
        this.handleConfirmation = (e) => {
            this.installScript(e);
        };
        // will be called from the confirmation dialog
        this.handleCancel = (e) => {
            this.setState({ notificationDialog: <div /> });
            setTimeout(
                function() {
                    this.setState({ disableModalClose: false });
                }
                        .bind(this),
                100
            );
        };
    }

    /* Runs when component is build */
    componentDidMount() {
        this.getDetails();
    }

    render() {
        const showMenuDialog = this.state.showMenu
            ? "display-block"
            : "display-none";

        const showInstallDialog = !this.state.showMenu
            ? "display-block"
            : "display-none";

        return (
            <Modal
        disableModalClose={this.state.disableModalClose}
        onClose={this.handleClose}
        show={this.state.show}
        header={this.state.openhab + " branches"}
            >
                {this.state.notificationDialog}
                <div className={showMenuDialog}>
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.branchRelease}
            value="release"
            content={
                <div>
                    <b>release</b> - Install or switch to the latest openHAB
                    release. Recomended for productive usage.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.branchTesting}
            value="testing"
            content={
                <div>
                    <b>testing</b> - Install or switch to the latest openHAB testing
                    build. This is only recomended for testing.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.branchSnapshot}
            value="snapshot"
            content={
                <div>
                    <b>snapshot</b> - Install or switch to the latest openHAB
                    snapshot. Snapshots contain the latest changes and therefore
                    they are not stable. Use them only for testing!
                </div>
            }
                    />
                    <br />
                    <div className="div-full-center">
                        <button
              className="pf-c-button pf-m-primary"
              onClick={(e) => {
                  this.updateBranche();
              }}
                        >
                            Update
                        </button>
                    </div>
                </div>
                <div className={showInstallDialog}>
                    <ProgressDialog
            onClose={this.handleClose}
            packageName={this.state.openhab + " (" + this.state.brancheToInstall + ")"}
            showResult={this.state.showResult}
            message={this.state.consoleMessage}
            success={this.state.successful}
            type="install"
                    />
                </div>
            </Modal>
        );
    }
}
