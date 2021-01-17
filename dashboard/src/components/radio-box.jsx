/* Returns a radio box. Allows following parameter:
 - onSelect() -> will be called on selection
 - value -> Value to send to onSelect function
 - checked -> Indicates if radio box is checked
 - label - includes a html value as label
 */

import React from "react";
import "../custom.scss";
import "../patternfly.scss";

export default class RadioBox extends React.Component {
    constructor() {
        super();
        this.state = {};
        this.onSelect = (e) => {
            this.props.onSelect && this.props.onSelect(e);
        };
    }

    componentDidUpdate() {}

    render() {
        return (
            <div className="padding-vertical">
                <div className="pf-c-radio display-flex">
                    <input
            className="pf-c-radio__input margin-top"
            type="radio"
            /* onClick={(e) => {
              this.onSelect();
            }} */
            onChange={(e) => {
                this.onSelect(this.props.value);
            }}
            checked={this.props.checked}
                    />
                    <div
            onClick={(e) => {
                this.onSelect(this.props.value);
            }}
            className="pf-c-radio__label radio-item"
                    >
                        {this.props.content}
                    </div>
                </div>
            </div>
        );
    }
}
