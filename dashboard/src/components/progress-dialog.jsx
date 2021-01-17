/* Returns a progress dialog
 - onClose() -> will be called on close
 - packageName -> package to install
 - showResult -> boolean to show final page, default is false
 - message -> Can contain a console output in case of errors
 - success -> indicate if success or error during installation, default is true
 - type -> "install", "update", "uninstall", "configure", "restore", backup"
 */

import React from "react";
import {
    faCheckCircle,
    faExclamationCircle,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";

import "../custom.scss";
import "../patternfly.scss";

export default class ProgressDialog extends React.Component {
    constructor() {
        super();
        this.state = {
            showConsoleOutput: false,
        };
        this.onClose = (e) => {
            this.props.onClose && this.props.onClose(e);
        };
        this.showConsoleOutput = (e) => {
            this.setState({
                showConsoleOutput: !this.state.showConsoleOutput
            });
        };
    }

    getFailureStatus() {
        if (this.props.success == true) {
            return "successful";
        }
        return "failed";
    }

    componentDidUpdate() {}

    render() {
        const showInstallingSpinner = !this.props.showResult
            ? "display-block"
            : "display-none";

        const showResult = this.props.showResult ? "display-block" : "display-none";

        const displaySuccess = this.props.success
            ? "display-block fa-5x success-icon"
            : "display-none";

        const displayError = this.props.success
            ? "display-none"
            : "display-block fa-5x failure-icon";

        const showInstallMessages = !this.props.success
            ? "display-block display-flex-center"
            : "display-none";

        const showConsoleOutput = this.state.showConsoleOutput
            ? "display-block display-flex-center"
            : "display-none";

        const progressTypes = [
            { type: "install", context: "installing", progress: "installation", result: "Installation" },
            { type: "update", context: "updating", progress: "update", result: "Update" },
            { type: "uninstall", context: "removing", progress: "removal", result: "Removal" },
            { type: "configure", context: "configuring", progress: "configuration", result: "Configuration" },
            { type: "restore", context: "restoring", progress: "restore", result: "Restore" },
            { type: "backup", context: "backup", progress: "backup", result: "Backup" }
        ];
        return (
            <div>
                <div className={showInstallingSpinner}>
                    <div className="div-full-center">
                        <h4>{progressTypes.map((a) => { if (a.type === this.props.type) { return a.context } })} {this.props.packageName} ...</h4>
                    </div>
                    <div className="div-full-center" style={{ paddingTop: "1rem", minHeight: "86px" }}>
                        <span
              className="pf-c-spinner"
              role="progressbar"
              aria-valuetext="Loading..."
                        >
                            <span className="pf-c-spinner__clipper" />
                            <span className="pf-c-spinner__lead-ball" />
                            <span className="pf-c-spinner__tail-ball" />
                        </span>
                    </div>
                    <div className="div-full-center">
                        <p>The {progressTypes.map((a) => { if (a.type === this.props.type) { return a.progress } })} will need some time please wait.</p>
                    </div>
                </div>
                <div className={showResult}>
                    <div className="div-full-center">
                        <FontAwesomeIcon className={displaySuccess} icon={faCheckCircle} />
                        <FontAwesomeIcon
              className={displayError}
              icon={faExclamationCircle}
                        />
                    </div>
                    <div style={{ paddingTop: "0.5rem" }} className="div-full-center">
                        <p>{progressTypes.map((a) => { if (a.type === this.props.type) { return a.result } })} of package {this.props.packageName} {this.getFailureStatus()}.</p>
                    </div>
                    <div className={showInstallMessages}>
                        <div className="div-full-center">
                            <button
                className="pf-c-button pf-m-primary"
                onClick={(e) => {
                    this.showConsoleOutput();
                }}
                            >
                                Show console messages
                            </button>
                        </div>
                    </div>
                    <div className={showConsoleOutput}>
                        <p className="console-text">{this.props.message}</p>
                    </div>
                </div>
            </div>
        );
    }
}
