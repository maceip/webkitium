#include "forms/FormFiller.h"

#include <algorithm>
#include <cctype>
#include <string_view>

namespace ng {
namespace {

std::string asciiLower(std::string_view in)
{
    std::string out;
    out.reserve(in.size());
    for (unsigned char c : in) {
        out.push_back(static_cast<char>(std::tolower(c)));
    }
    return out;
}

bool containsInsensitive(std::string_view haystack, std::string_view needle)
{
    if (needle.empty())
        return true;
    const auto h = asciiLower(haystack);
    const auto n = asciiLower(needle);
    return h.find(n) != std::string::npos;
}

std::string lastAutocompleteToken(std::string_view autocompleteLower)
{
    std::string_view s = autocompleteLower;
    while (!s.empty() && (s.back() == ' ' || s.back() == '\t'))
        s.remove_suffix(1);
    const auto pos = s.rfind(' ');
    if (pos == std::string_view::npos)
        return std::string(s);
    return std::string(s.substr(pos + 1));
}

std::optional<std::string> suggestionForToken(std::string_view token, const AutofillProfile& profile)
{
    const std::string t = asciiLower(token);
    if (t == "given-name" || t == "fname" || t == "first")
        return profile.givenName.empty() ? std::optional<std::string>() : std::optional(profile.givenName);
    if (t == "additional-name" || t == "middle-name" || t == "mname")
        return profile.additionalName.empty() ? std::optional<std::string>() : std::optional(profile.additionalName);
    if (t == "family-name" || t == "lname" || t == "last")
        return profile.familyName.empty() ? std::optional<std::string>() : std::optional(profile.familyName);
    if (t == "name" || t == "fullname" || t == "full-name" || t == "username")
        return profile.fullName.empty() ? std::optional<std::string>() : std::optional(profile.fullName);
    if (t == "email")
        return profile.email.empty() ? std::optional<std::string>() : std::optional(profile.email);
    if (t == "tel" || t == "tel-national" || t == "tel-local")
        return profile.tel.empty() ? std::optional<std::string>() : std::optional(profile.tel);
    if (t == "organization" || t == "organization-name" || t == "company")
        return profile.organization.empty() ? std::optional<std::string>() : std::optional(profile.organization);
    if (t == "street-address" || t == "address-line1")
        return profile.streetAddress.empty() ? std::optional<std::string>() : std::optional(profile.streetAddress);
    if (t == "address-line2" || t == "address-line3")
        return profile.addressLine2.empty() ? std::optional<std::string>() : std::optional(profile.addressLine2);
    if (t == "address-level2" || t == "city" || t == "locality")
        return profile.locality.empty() ? std::optional<std::string>() : std::optional(profile.locality);
    if (t == "address-level1" || t == "region" || t == "state" || t == "province")
        return profile.region.empty() ? std::optional<std::string>() : std::optional(profile.region);
    if (t == "postal-code" || t == "zip" || t == "zip-code")
        return profile.postalCode.empty() ? std::optional<std::string>() : std::optional(profile.postalCode);
    if (t == "country" || t == "country-name")
        return profile.country.empty() ? std::optional<std::string>() : std::optional(profile.country);
    return std::nullopt;
}

std::optional<std::string> suggestionFromHeuristicName(const HtmlFormField& field, const AutofillProfile& profile)
{
    const std::string blob = asciiLower(field.name + " " + field.id);
    if (containsInsensitive(blob, "email") || blob.find("e-mail") != std::string::npos)
        return profile.email.empty() ? std::nullopt : std::optional(profile.email);
    if (containsInsensitive(blob, "phone") || containsInsensitive(blob, "tel") || containsInsensitive(blob, "mobile"))
        return profile.tel.empty() ? std::nullopt : std::optional(profile.tel);
    if (containsInsensitive(blob, "fname") || containsInsensitive(blob, "first") || containsInsensitive(blob, "givenname"))
        return profile.givenName.empty() ? std::nullopt : std::optional(profile.givenName);
    if (containsInsensitive(blob, "lname") || containsInsensitive(blob, "last") || containsInsensitive(blob, "familyname"))
        return profile.familyName.empty() ? std::nullopt : std::optional(profile.familyName);
    if (containsInsensitive(blob, "zip") || containsInsensitive(blob, "postal"))
        return profile.postalCode.empty() ? std::nullopt : std::optional(profile.postalCode);
    if (containsInsensitive(blob, "city"))
        return profile.locality.empty() ? std::nullopt : std::optional(profile.locality);
    if (containsInsensitive(blob, "state") || containsInsensitive(blob, "province"))
        return profile.region.empty() ? std::nullopt : std::optional(profile.region);
    if (containsInsensitive(blob, "address") && !containsInsensitive(blob, "email"))
        return profile.streetAddress.empty() ? std::nullopt : std::optional(profile.streetAddress);
    return std::nullopt;
}

} // namespace

std::optional<std::string> FormFiller::suggestion(const HtmlFormField& field, const AutofillProfile& profile)
{
    if (!field.autocomplete.empty()) {
        const std::string ac = asciiLower(field.autocomplete);
        if (ac == "off" || ac == "false" || ac == "nope")
            return std::nullopt;
        if (const auto v = suggestionForToken(lastAutocompleteToken(ac), profile))
            return v;
    }

    const std::string typeLower = asciiLower(field.type);
    if (typeLower == "email" && !profile.email.empty())
        return profile.email;
    if ((typeLower == "tel" || typeLower == "telephone") && !profile.tel.empty())
        return profile.tel;

    return suggestionFromHeuristicName(field, profile);
}

} // namespace ng
