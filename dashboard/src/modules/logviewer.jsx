import React from "react";
import cockpit from "cockpit";
import ReactDOM from "react-dom";
import ScrollToBottom from "react-scroll-to-bottom";
import { TextInput } from "@patternfly/react-core";
import { faPlay, faPause } from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { getopenHABLogDir } from "../functions/openhab.js";

import "../custom.scss";
import "../patternfly.scss";

export default class LogViewer extends React.Component {
    /* Watch the openhab event log for new changes */
    async read_OpenHABLog() {
        this.setState({
            watchProcessOpenhab: cockpit
                    .file(await getopenHABLogDir() + "/openhab.log")
                    .watch((data, filename) => {
                        if (filename) {
                            // if this is not the first run start here to read only changes since last run
                            if (this.state.lastOHLogEvent !== "") {
                                // split by last know event if available and merge events in result table
                                this.setState({
                                    lastOHLogEvent: this.updateTable(
                                        data,
                                        this.state.lastOHLogEvent
                                    ),
                                });
                                // display the log results
                                this.displayLog();
                            } else {
                                // if this is the first time data will be read start here
                                if (data !== "" && data !== undefined) {
                                    // read last 50 events if this is the first run to avoid displaying the whole logo
                                    data = this.getLast50Messages(data);
                                    // create a table of the event
                                    var table = this.createTable(data);
                                    // if events found merge in result table and mark last element to split
                                    if (table.length > 0) {
                                        var e = table[table.length - 1];
                                        this.setState({
                                            lastOHLogEvent:
                      e.time +
                      "[" +
                      e.level +
                      "] [" +
                      e.source +
                      "] - " +
                      e.message +
                      "\n",
                                            resultTable: table,
                                        });
                                        // read now oh events.log and get all events that are newer than the latest oh event that is cached
                                        this.read_EventsLog();
                                        this.displayLog();
                                    }
                                }
                            }
                        }
                    }),
        });
    }

    /* Watch the events log for new changes */
    async read_EventsLog() {
    /* Watch the events log for new changes */
        this.setState({
            watchProcessEvents: cockpit
                    .file(await getopenHABLogDir() + "/events.log")
                    .watch((data, filename) => {
                        if (filename) {
                            // if this is not the first run start here to read only changes since last run
                            if (this.state.lastEventsLogEvent !== "") {
                                // split by last know event if available and merge events in result table
                                this.setState({
                                    lastEventsLogEvent: this.updateTable(
                                        data,
                                        this.state.lastEventsLogEvent
                                    ),
                                });
                            } else {
                                // if this is the first time data will be read start here
                                if (data !== "" && data !== undefined) {
                                    // create a table of the event
                                    var table = this.createTable(data);
                                    var tmp = [];
                                    // filter by alll events that are newer than th elatest oh event
                                    table.forEach((t) => {
                                        if (
                                            new Date(
                                                t.time.trim().replace(/\s+/g, "T") + "Z"
                                            ).getTime() >
                    new Date(
                        this.state.resultTable[0].time
                                .trim()
                                .replace(/\s+/g, "T") + "Z"
                    )
                                        ) {
                                            tmp.push(t);
                                        }
                                    });
                                    // if events found merge in result table and mark last element to split
                                    if (tmp.length > 1) {
                                        var e = tmp[tmp.length - 1];
                                        this.setState({
                                            lastEventsLogEvent:
                      e.time +
                      "[" +
                      e.level +
                      "] [" +
                      e.source +
                      "] - " +
                      e.message +
                      "\n",
                                            resultTable: this.state.resultTable.concat(tmp),
                                        });
                                    }
                                }
                            }
                            // display the log results
                            this.displayLog();
                        }
                    }),
        });
    }

    /* Returns the last 50 lines of a log file */
    getLast50Messages(data) {
        var currentRowCount = data.split("\n").length;
        var i;
        var result = "";
        for (i = currentRowCount - 50; i < currentRowCount - 1; i++) {
            if (i > 0) result += data.split("\n")[i] + "\n";
        }
        return result;
    }

    /* Credates a data table and stores the events from the input string inside this. */
    createTable(data) {
        var tmp = [];
        var logentryFound = false;
        // split by each new line
        data.split("\n").forEach((d) => {
            if (d !== "") {
                // if the first part of the string is a valid date makr this as a new log entry
                if (
                    isNaN(
                        new Date(
                            d.split("[")[0].trim().replace(/\s+/g, "T") + "Z"
                        ).getTime()
                    ) == false
                ) {
                    // Set log entry found to true. If in next line there is no new valid date, the line will be added to this event
                    logentryFound = true;
                    // split by time, level,source and message to store in result table
                    var time = d.split("[")[0];
                    var level = d.split("[")[1].split("]")[0];
                    var source = d.split("[")[2].split("]")[0];
                    var message = d.split(level + "] [" + source + "] - ")[1];
                    tmp.push({
                        time: time,
                        level: level,
                        source: source,
                        message: message,
                    });
                }
                if (
                    isNaN(
                        new Date(
                            d.split("[")[0].trim().replace(/\s+/g, "T") + "Z"
                        ).getTime()
                    ) == true &&
          logentryFound == true
                ) {
                    // if this is no new log append to previous message
                    message = tmp[tmp.length - 1].message + "\n" + d;
                    tmp[tmp.length - 1].message = message;
                }
            }
        });
        return tmp;
    }

    /* adds all events after the splitBy value to resultTable */
    updateTable(data, splitBy) {
    // split log by last known message to get only the newest messages that where neot processed
        data = data.split(splitBy)[1];
        var table = this.createTable(data);
        this.setState({ resultTable: this.state.resultTable.concat(table) }); // merge tables
        var e = table[table.length - 1];
        return (
            e.time + "[" + e.level + "] [" + e.source + "] - " + e.message + "\n"
        );
    }

    /* displays the log fiel */
    displayLog() {
        if (this.state.pauseLog == false) {
            var tmp = "";
            // sort by date
            this.setState({
                resultTable: this.state.resultTable.sort((a, b) =>
                    a.time > b.time ? 1 : -1
                ),
            });
            // create inner html of all table rows
            this.state.resultTable.forEach((e) => {
                // filter log
                if (this.filterEventsByExpression(e.time + "[" + e.level + "] [" + e.source + "] - " + e.message, this.state.eventFilterText) == true) {
                    tmp += e.time + "[" + this.formatLogLevel(e.level) + '] [<div style="display: inline-block;">' + e.source + "</div>] - " + e.message + "<br />";
                }
            });
            this.setState({ displayResult: tmp });
        }
    }

    filterEventsByExpression(str, wildcard) {
        if (wildcard == '*' || wildcard === "") return true;

        wildcard = wildcard.replace(/\./g, '\\.');
        wildcard = wildcard.replace(/\?/g, '.');
        wildcard = wildcard.replace(/\\/g, '\\\\');
        wildcard = wildcard.replace(/\//g, '\\/');
        wildcard = wildcard.replace(/\*/g, '(.+?)');

        var re = new RegExp(wildcard, 'i');
        return re.test(str);
    }

    /* Formats the log level "Ifo, Warning..." with colors */
    formatLogLevel(level) {
        if (level === "DEBUG") {
            return (
                '<div style="color: blue; display: inline-block">' + level + "</div>"
            );
        }
        if (level === "INFO ") {
            return (
                '<div style="color: #008000; display: inline-block">' + level + "</div>"
            );
        }
        if (level === "WARN ") {
            return (
                '<div style="color: #FFA500; display: inline-block">' + level + "</div>"
            );
        }
        if (level === "ERROR") {
            return (
                '<div style="color: red; display: inline-block">' + level + "</div>"
            );
        }
        return '<div style="display: inline-block">' + level + "</div>";
    }

    constructor() {
        super();
        this.state = {
            watchProcessOpenhab: "",
            watchProcessEvents: "",
            eventFilterText: "",
            hideLabel: false,
            smallSearchBox: false,
            resultTable: [],
            displayResult: <div />,
            lastOHLogEvent: "",
            lastEventsLogEvent: "",
            pauseLog: false,
        };
        // handler for closing the modal
        this.onClose = (e) => {
            if (!this.props.disableModalClose)
                this.props.onClose && this.props.onClose(e);
        };
        // handler for outside click to close modal
        this.handleClickOutsideModal = (e) => {
            const domNode = ReactDOM.findDOMNode(this.state.node);
            if (!domNode.contains(e.target)) {
                this.onClose(e);
            }
        };
        // handler for esc key press to close modal
        this.handleModalEscKeyEvent = (e) => {
            if (e.keyCode == 27) this.onClose(e);
        };
        // hide title if ohn smartphone to avoid to small search box
        this.resize = (e) => {
            this.setState({
                hideLabel: window.innerWidth <= 540,
                smallSearchBox:
          window.innerWidth <= 445 ||
          (window.innerWidth >= 540 && window.innerWidth <= 590),
            });
        };
        this.handleTextInputChange = (e) => {
            this.setState({ eventFilterText: e }, () => {
                this.displayLog();
            });
        };
        this.handleLogPause = (e) => {
            if (this.state.pauseLog == true) {
                this.setState({ pauseLog: false });
                this.displayLog();
            } else {
                this.setState({ pauseLog: true });
            }
        };
    /* Modal action handler end */
    }

    /* Runs when component is added to DOM */
    componentDidMount() {
        this.resize();
        window.addEventListener("resize", this.resize, false);
        document.addEventListener("click", this.handleClickOutsideModal, false);
        document.addEventListener("keydown", this.handleModalEscKeyEvent, false);
        this.read_OpenHABLog();
    }

    /* Runs when component is removed from DOM */
    componentWillUnmount() {
        window.removeEventListener("resize", this.resize, false);
        document.removeEventListener("click", this.handleClickOutsideModal, false);
        document.removeEventListener("keydown", this.handleModalEscKeyEvent, false);
    }

    render() {
        const showLabel = this.state.hideLabel ? "display-none" : "display-block";
        const searchBox = this.state.smallSearchBox
            ? "search-box-small"
            : "search-box";
        const displayPlayIcon = this.state.pauseLog
            ? "display-block"
            : "display-none";
        const displayPauseIcon = this.state.pauseLog
            ? "display-none"
            : "display-block";

        return (
            <div>
                <div className="logViewer-background" />
                <div
          className="logViewer-content"
          ref={(node) => {
              this.state.node = node;
          }}
                >
                    <div className="content-header-extra display-flex">
                        <div className="justify-content-space-between width-max">
                            <div className="display-flex">
                                <div className={showLabel} style={{ paddingRight: "1rem" }}>
                                    <h3>LogViewer</h3>
                                </div>
                                <div className="flex-direction-row">
                                    <TextInput
                    className={searchBox}
                    value={this.state.eventFilterText}
                    type="text"
                    id="iDontNeedYou"
                    onChange={this.handleTextInputChange}
                                    />
                                    <button
                    className="pf-c-button"
                    onClick={(e) => {
                        this.handleLogPause();
                    }}
                                    >
                                        <FontAwesomeIcon
                      className={displayPlayIcon}
                      icon={faPlay}
                                        />
                                        <FontAwesomeIcon
                      className={displayPauseIcon}
                      icon={faPause}
                                        />
                                    </button>
                                </div>
                            </div>
                            <button
                className="pf-c-button close-button"
                type="button"
                onClick={(e) => {
                    this.onClose(e);
                }}
                            >
                                X
                            </button>
                        </div>
                    </div>
                    <div className="console-logs-bg">
                        <ScrollToBottom className="console-logs">
                            <pre
                className="console-log-pre"
                dangerouslySetInnerHTML={{ __html: this.state.displayResult }}
                            />
                        </ScrollToBottom>
                    </div>
                </div>
            </div>
        );
    }
}
