import React from "react";
import "../custom.scss";
import "../patternfly.scss";

export default class Dropdown extends React.Component {
    constructor() {
        super();
        this.state = {};

        this.onSelect = (e) => {
            document.removeEventListener("click", this.handleDropdown, false);
            this.props.onSelect && this.props.onSelect(e);
        };
        this.handleDropdown = (e) => {
            this.clickListener();

            this.setState({
                showDropdown: !this.state.showDropdown,
            });
        };
    }

    clickListener() {
        if (this.state.showDropdown) {
            document.removeEventListener("click", this.handleDropdown, false);
        } else {
            document.addEventListener("click", this.handleDropdown, false);
        }
    }

    componentDidUpdate() {}

    render() {
        const classesDropDown = this.state.showDropdown
            ? "display-block dropdown-body"
            : "display-none";

        return (
            <div className="dropdown">
                <div className="pf-c-button pf-m-primary">
                    <button
            onClick={(e) => {
                this.onSelect(this.props.value);
            }}
            className="dropdown-button"
                    >
                        {this.props.label}
                    </button>
                    <button
            className="dropdown-icon"
            onClick={(e) => {
                this.handleDropdown();
            }}
                    >
                        &#x25BC;
                    </button>
                </div>
                <ul
          className={classesDropDown}
          aria-labelledby="dropdown-expanded-button"
                >
                    {this.props.children}
                </ul>
            </div>
        );
    }
}
