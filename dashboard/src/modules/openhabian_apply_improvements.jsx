import React from "react";
import RadioBox from "../components/radio-box.jsx";
import Modal from "../components/modal.jsx";
import ProgressDialog from "../components/progress-dialog.jsx";
import { validateResponse } from "../functions/helpers.js";
import { applyImprovments } from "../functions/openhabian.js";

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class OpenHABianApplyImprovements extends React.Component {
    async installPackage() {
        var message = "Package " + this.state.selectedPackageName + " will be updated.";
        console.log(message);
        this.setState(
            {
                showMenu: false,
                disableModalClose: true,
            });
        var data = await applyImprovments(this.state.selectedPackage);
        if (validateResponse(data)) {
            this.installSuccesful(data);
        } else {
            this.installFailure(data);
        }
    }

    // will be called if installation was succesfull
    installSuccesful(data) {
        console.log("Package installation done. See Result below:.\n" + data);
        this.setState({
            consoleMessage: data,
            disableModalClose: false,
            showResult: true,
            successful: true,
        });
    }

    // will be called if installation failed
    installFailure(data) {
        var message = "Could not install the package '" + this.state.selectedPackageName + "'. Output: \n" + data;
        console.error(message);
        this.setState({
            showResult: true,
            successful: false,
            consoleMessage: message,
            disableModalClose: false,
        });
    }

    // Resets all selection elements. important for interactiv gui
    resetSelection() {
        this.setState({
            packageSystemPackages: false,
            packageBashVim: false,
            packageSystemTweaks: false,
            packagePermissions: false,
            packageFireMotD: false,
            packageSamba: false,
        });
    }

    constructor() {
        super();
        this.state = {
            show: true,
            showMenu: true,
            showResult: false,
            successful: false,
            packageSystemPackages: true,
            packageBashVim: false,
            packageSystemTweaks: false,
            packagePermissions: false,
            packageFireMotD: false,
            packageSamba: false,
            selectedPackage: "packageSystemPackages",
            selectedPackageName: "System Packages",
            consoleMessage: "",
            disableModalClose: false,
        };

        // handler for closing the modal
        this.handleClose = (e) => {
            if (!this.state.disableModalClose)
                this.props.onClose && this.props.onClose(e);
        };

        // handles the selection change (radio button update)
        this.handleSelectionChange = (e) => {
            this.resetSelection();
            if (e === "packageSystemPackages")
                this.setState({
                    packageSystemPackages: true,
                    selectedPackage: "packageSystemPackages",
                    selectedPackageName: "System Packages",
                });
            if (e === "packageBashVim")
                this.setState({
                    packageBashVim: true,
                    selectedPackage: "packageBashVim",
                    selectedPackageName: "Bash & Vim",
                });
            if (e === "packageSystemTweaks")
                this.setState({
                    packageSystemTweaks: true,
                    selectedPackage: "packageSystemTweaks",
                    selectedPackageName: "System Tweaks",
                });
            if (e === "packagePermissions")
                this.setState({
                    packagePermissions: true,
                    selectedPackage: "packagePermissions",
                    selectedPackageName: "Fix-Permissions",
                });
            if (e === "packageFireMotD")
                this.setState({
                    packageFireMotD: true,
                    selectedPackage: "packageFireMotD",
                    selectedPackageName: "FireMotD",
                });
            if (e === "packageSamba")
                this.setState({
                    packageSamba: true,
                    selectedPackage: "packageSamba",
                    selectedPackageName: "Samba share",
                });
        };
    }

    render() {
        const showMenu = this.state.showMenu ? "display-block" : "display-none";

        const showInstallDialog = !this.state.showMenu
            ? "display-block"
            : "display-none";

        return (
            <Modal
        disableModalClose={this.state.disableModalClose}
        onClose={this.handleClose}
        show={this.state.show}
        header="Apply Improvements"
            >
                <div className={showMenu}>
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.packageSystemPackages}
            value="packageSystemPackages"
            content={
                <div>
                    <b>System packages</b> - Install needed and recomended system
                    packages on your system."
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.packageBashVim}
            value="packageBashVim"
            content={
                <div>
                    <b>Bash & VIM</b> - Updates customized openHABian settings for
                    bash, vim and nano."
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.packageSystemTweaks}
            value="packageSystemTweaks"
            content={
                <div>
                    <b>System Tweaks</b> - Adds /srv mounts and updates settings
                    that are typicaly for openHAB.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.packagePermissions}
            value="packagePermissions"
            content={
                <div>
                    <b>Fix Permissions</b> - Update file permissions of commonly
                    used files and folders.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.packageFireMotD}
            value="packageFireMotD"
            content={
                <div>
                    <b>FireMotD</b> - Upgrade the program behind the system overview
                    on SSH login.
                </div>
            }
                    />
                    <RadioBox
            onSelect={this.handleSelectionChange}
            checked={this.state.packageSamba}
            value="packageSamba"
            content={
                <div>
                    <b>Samba shares</b> - Install the Samba file sharing service and
                    set up openHAB shares.
                </div>
            }
                    />
                    <br />
                    <div className="div-full-center">
                        <button
              className="pf-c-button pf-m-primary"
              onClick={(e) => {
                  this.installPackage();
              }}
                        >
                            Install
                        </button>
                    </div>
                </div>
                <div className={showInstallDialog}>
                    <ProgressDialog
            onClose={this.handleClose}
            packageName={this.state.selectedPackageName}
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
