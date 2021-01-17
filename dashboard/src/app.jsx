import cockpit from "cockpit";
import React from "react";
import OHStatus from "./openhab-status.jsx";
import Tools from "./tools.jsx";
import CheckDefaultUser from "./modules/check_default_user.jsx";
import CheckopenHABianUpdates from "./modules/check_openhabian_updates.jsx";
import "./app.scss";
import "./custom.scss";

const _ = cockpit.gettext;

export class Application extends React.Component {
    constructor() {
        super();
        this.state = {
            hostname: _("Unknown"),
        };
        cockpit.file("/etc/hostname").watch((content) => {
            this.setState({ hostname: content.trim() });
        });
    }

    render() {
        return (
            <div>
                <div className="pf-c-page">
                    <main role="main" className="pf-c-page__main" tabIndex="-1">
                        <section className="pf-c-page__main-section pf-m-light ct-overview-header">
                            <div className="ct-overview-header-hostname">
                                <h1>openHABian Dashboard</h1>
                            </div>
                        </section>
                        <section className="pf-c-page__main-section">
                            <CheckDefaultUser />
                            <CheckopenHABianUpdates />
                            <div id="gallery" className="pf-l-gallery pf-m-gutter">
                                <OHStatus />
                                <Tools />
                            </div>
                        </section>
                    </main>
                </div>
            </div>
        );
    }
}
