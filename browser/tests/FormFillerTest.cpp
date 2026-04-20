#include "forms/FormFiller.h"

#include <cassert>

int main()
{
    ng::AutofillProfile p;
    p.givenName = "A";
    p.familyName = "B";
    p.email = "a@b.co";

    ng::HtmlFormField off;
    off.autocomplete = "off";
    assert(!ng::FormFiller::suggestion(off, p));

    ng::HtmlFormField ac;
    ac.autocomplete = "shipping email";
    assert(ng::FormFiller::suggestion(ac, p) == "a@b.co");

    ng::HtmlFormField org;
    org.autocomplete = "organization";
    p.organization = "Org";
    assert(ng::FormFiller::suggestion(org, p) == "Org");

    return 0;
}
