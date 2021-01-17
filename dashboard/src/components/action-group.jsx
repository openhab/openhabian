import React from "react";
import {
    ActionList,
    ActionListItem,
    Dropdown,
    KebabToggle
} from '@patternfly/react-core';

import "../custom.scss";
import "../patternfly.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

export default class ActionGroup extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            isOpen: false,
        };
        this.handleToggle = (event) => {
            this.set_event_Handler();
            this.setState({
                isOpen: !this.state.isOpen
            });
        };
        this.handleSelect = event => {
            this.set_event_Handler();
            this.setState({
                isOpen: !this.state.isOpen
            });
        };
    }

    set_event_Handler() {
        if (this.state.isOpen) {
            document.removeEventListener("click", this.handleSelect, false);
        } else {
            document.addEventListener("click", this.handleSelect, false);
        }
    }

    componentWillUnmount() {
        document.removeEventListener("click", this.handleSelect, false);
    }

    render() {
        return (
            <ActionList>
                <ActionListItem>
                    <Dropdown
                    toggle={<KebabToggle onToggle={this.handleToggle} />}
                    isOpen={this.state.isOpen}
                    isPlain
                    dropdownItems={this.props.dropdownItems}
                    position={this.props.position}
                    />
                </ActionListItem>
            </ActionList>
        );
    }
}
