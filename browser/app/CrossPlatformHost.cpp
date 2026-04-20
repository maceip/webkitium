#include "forms/FormFiller.h"
#include "tabs/BrowserCommandController.h"
#include "tabs/BrowserStateModel.h"

#include <cstdlib>
#include <iostream>

namespace {

bool checkFill(const ng::HtmlFormField& field, const ng::AutofillProfile& profile, const char* expect)
{
    const auto v = ng::FormFiller::suggestion(field, profile);
    return v && *v == expect;
}

} // namespace

int main()
{
    ng::AutofillProfile profile;
    profile.givenName = "Ada";
    profile.familyName = "Lovelace";
    profile.fullName = "Ada Lovelace";
    profile.email = "ada@example.com";
    profile.tel = "+1 555 0100";
    profile.streetAddress = "1 Analytical Engine Rd";
    profile.locality = "London";
    profile.postalCode = "SW1A 1AA";
    profile.country = "GB";

    ng::HtmlFormField emailField;
    emailField.name = "user_email";
    emailField.autocomplete = "email";

    ng::HtmlFormField heuristicZip;
    heuristicZip.name = "postal";
    heuristicZip.autocomplete = "";

    ng::HtmlFormField typeTel;
    typeTel.name = "x";
    typeTel.type = "tel";

    if (!checkFill(emailField, profile, "ada@example.com")) {
        std::cerr << "cross-platform host: email autofill mismatch\n";
        return EXIT_FAILURE;
    }
    if (!checkFill(heuristicZip, profile, "SW1A 1AA")) {
        std::cerr << "cross-platform host: postal heuristic mismatch\n";
        return EXIT_FAILURE;
    }
    if (!checkFill(typeTel, profile, "+1 555 0100")) {
        std::cerr << "cross-platform host: tel type mismatch\n";
        return EXIT_FAILURE;
    }

    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);
    const auto windowId = commands.newWindow(ng::TabStripMode::Horizontal);
    const auto tabId = commands.newTab(windowId, "about:blank", true);
    if (!tabId) {
        std::cerr << "cross-platform host: failed to create tab\n";
        return EXIT_FAILURE;
    }

    std::cout << "ng_cross_platform_host: form filler ok; window " << windowId << " tab " << tabId.value() << '\n';
    return EXIT_SUCCESS;
}
