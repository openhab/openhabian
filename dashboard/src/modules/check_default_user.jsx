import React from "react";
import Modal from "../components/modal.jsx";
import { Alert, TextInput } from "@patternfly/react-core";
import { validateResponse } from "../functions/helpers.js";
import { defaultSystemPasswordChanged, setDefaultSystemPassword } from "../functions/openhabian.js";
import ProgressDialog from "../components/progress-dialog.jsx";

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class CheckDefaultUser extends React.Component {
    // check if the system runs with default openhabian/pi password
    async checkForDefaultPassword() {
        var data = await defaultSystemPasswordChanged();
        if (data === false) {
            this.setState({
                defaultPasswordChanged: false,
            });
            return;
        }
        this.setState({ defaultPasswordChanged: true });
    }

    // check new password if complex and valid. if yes run change password
    setPassword() {
        if (
            this.state.newPassword !== "" &&
      this.state.newPassword === this.state.confirmNewPassword
        ) {
            if (this.checkPasswordStrength(this.state.newPassword) == true) {
                this.setState({ displayInvalidPassword: false, hidePasswordDialog: true });
                this.cmdChangePassword();
            } else {
                this.setState({
                    displayInvalidPassword: true,
                    invalidPasswordMessage:
            "The password must contain 8 characters and special characters",
                });
            }
        } else {
            if (this.checkPasswordStrength)
                this.setState({
                    displayInvalidPassword: true,
                    invalidPasswordMessage: "Passwords empty or do not match.",
                });
        }
    }

    // check for password complexity
    checkPasswordStrength(password) {
        if (
            /.{8,}/.test(password) /* at least 8 characters */ *
        (/.{12,}/.test(password) /* bonus if longer */ +
          /[a-z]/.test(password) /* a lower letter */ +
          /[A-Z]/.test(password) /* a upper letter */ +
          /\d/.test(password) /* a digit */ +
          /[^A-Za-z0-9]/.test(password)) /* a special character */ >=
      4
        ) {
            return true;
        }
        return false;
    }

    // changes the password of the openhabian or pi user
    async cmdChangePassword() {
        var data = await setDefaultSystemPassword(this.state.newPassword);
        if (validateResponse(data)) {
            this.configSuccesful(data);
            this.checkForDefaultPassword();
        } else {
            this.configFailure(data);
        }
    }

    // will be called if installation was succesfull
    configSuccesful(data) {
        console.log("Password updated.\n" + data);
        this.setState({
            showLoading: false,
            showResult: true,
            consoleMessage: data,
            successful: true,
            disableModalClose: false,
        });
    }

    // will be called if installation failed
    configFailure(data) {
        var message = "Error could not install the latest openHAB-cockpit updates. Output: \n" + data;
        console.error(message);
        this.setState({
            showLoading: false,
            showResult: true,
            successful: false,
            consoleMessage: message,
            disableModalClose: false,
        });
    }

    constructor() {
        super();
        this.state = {
            defaultPasswordChanged: true,
            showModal: false,
            newPassword: "",
            confirmNewPassword: "",
            displayInvalidPassword: false,
            invalidPasswordMessage: "Passwords empty or do not match.",
            successful: true,
            showResult: false,
            consoleMessage: "Update done. Please reload the page to see them.",
            disableModalClose: false,
        };
        // handles the modal open and close
        this.handleModalShow = (e) => {
            this.setState({
                showModal: !this.state.showModal,
                showResult: false,
                newPassword: "",
                confirmNewPassword: "",
                displayInvalidPassword: false
            });
        };
        // sends ui input of password field
        this.handleNewPasswordText = (e) => {
            this.setState({
                newPassword: e,
            });
        };
        // sends ui input of confirm password field
        this.handleConfirmNewPasswordText = (e) => {
            this.setState({
                confirmNewPassword: e,
            });
        };
    }

    componentDidMount() {
        this.checkForDefaultPassword();
    }

    componentWillUnmount() {}

    render() {
        const showDefaultPasswordWarning = this.state.defaultPasswordChanged
            ? "display-none"
            : "display-block";

        const showLoading = this.state.hidePasswordDialog ? "display-block" : "display-none";

        const hidePasswordDialog = this.state.showResult
            ? "display-none"
            : "display-block";

        const displayInvalidPassword = this.state.displayInvalidPassword
            ? "display-block div-full-center"
            : "display-none";

        return (
            <div>
                <div className={showDefaultPasswordWarning}>
                    <Alert
            isInline
            variant="danger"
            title="Default password not changed!"
                    >
                        <p>
                            Running your system with the default password for openhabian/pi is a security risk and should not be
                            done.{" "}
                            <a
                onClick={(e) => {
                    this.handleModalShow();
                }}
                            >
                                You can change the password here
                            </a>
                        </p>
                    </Alert>
                </div>
                <Modal
          disableModalClose={this.state.disableModalClose}
          onClose={this.handleModalShow}
          show={this.state.showModal}
          header="Change user password."
                >
                    <div className={hidePasswordDialog}>
                        <div className="div-full-center">
                            <div style={{ Top: "0.5rem" }}>
                                <label style={{ width: "90px" }}>password:</label>
                                <TextInput
                  style={{ display: "inline-block", width: "200px" }}
                  value={this.state.newPassword}
                  type="password"
                  id="newpassword"
                  onChange={this.handleNewPasswordText}
                                />
                            </div>
                        </div>
                        <div className="div-full-center">
                            <div style={{ Top: "0.5rem" }}>
                                <label style={{ width: "90px" }}>confirm:</label>
                                <TextInput
                  style={{ display: "inline-block", width: "200px" }}
                  value={this.state.confirmNewPassword}
                  type="password"
                  id="confirmpassword"
                  onChange={this.handleConfirmNewPasswordText}
                                />
                            </div>
                        </div>
                        <div className={displayInvalidPassword}>
                            <label style={{ padding: "0.5rem", color: "red" }}>
                                {this.state.invalidPasswordMessage}
                            </label>
                        </div>
                        <div style={{ paddingTop: "0.5rem" }} className="div-full-center">
                            <button
                className="pf-c-button pf-m-primary"
                onClick={(e) => {
                    this.setPassword();
                }}
                            >
                                Set password
                            </button>
                        </div>
                    </div>
                    <div className={showLoading}>
                        <ProgressDialog
            onClose={this.handleModalShow}
            packageName="user password"
            showResult={this.state.showResult}
            message={this.state.consoleMessage}
            success={this.state.successful}
            type="configure"
                        />
                    </div>
                </Modal>
            </div>
        );
    }
}
