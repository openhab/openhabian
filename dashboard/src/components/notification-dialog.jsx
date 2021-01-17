// Returns a notification dialog
// onConfirm() -> if procided a confirm button is available
// onCancel() -> if provided a cancel button is available
// type -> "info", "warning", "error", displays the type of error
// message -> Contains the message to display

import React from "react";
import {
    faInfoCircle,
    faExclamationTriangle,
    faExclamationCircle
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";

import "../custom.scss";
import "../patternfly.scss";

export default class NotificationDialog extends React.Component {
    constructor() {
        super();
        this.state = {};
        // Calls the confirm methode passed to the component
        this.onConfirm = (e) => {
            this.props.onConfirm && this.props.onConfirm(this.props.value);
        };
        // Calls the cancel methode passed to the component
        this.onCancel = (e) => {
            this.props.onCancel && this.props.onCancel(e);
        };
    }

    render() {
        const hideConfirmButton = this.props.onConfirm
            ? "display-block pf-c-button pf-m-primary"
            : "display-none";

        const showMessage = this.props.message
            ? "display-block div-full-center"
            : "display-none";

        const hideCancelButton = this.props.onCancel
            ? "display-block pf-c-button pf-m-secondary"
            : "display-none";

        const displayIcon = [
            { type: "info", icon: faInfoCircle, className: "fa-4x info-icon" },
            { type: "warning", icon: faExclamationTriangle, className: "fa-4x warn-icon" },
            { type: "error", icon: faExclamationCircle, className: "fa-4x error-icon" }
        ];

        return (
            <div>
                <div className="modal-backdrop in" />
                <div className="modal-container in" style={{ marginTop: "5rem", margin: "1rem" }}>
                    <div className="modal-dialog" style={{ maxWidth: "40rem" }}>
                        <div
              className="modal-content"
                        >
                            <div className="modal-body scroll">
                                <div className="div-full-center">
                                    {displayIcon.map(item => {
                                        if (item.type === this.props.type) {
                                            return <FontAwesomeIcon key={item.type} icon={item.icon} className={item.className} />;
                                        }
                                    })}
                                </div>
                                <div className={showMessage}>
                                    <p className="notification-message">{this.props.message}</p>
                                </div>
                                <div className="div-full-center">
                                    {this.props.children}
                                </div>
                                <br />
                                <div className="div-full-center">
                                    <div>
                                        <button
                                        style={{ marginRight: "0.5rem" }}
                                        className={hideConfirmButton}
                                        onClick={(e) => {
                                            this.onConfirm();
                                        }}
                                        >
                                            OK
                                        </button>
                                        <button
                                        style={{ marginLeft: "0.5rem" }}
                                        className={hideCancelButton}
                                        onClick={(e) => {
                                            this.onCancel();
                                        }}
                                        >
                                            Cancel
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        );
    }
}
