package main

import "strings"

// Match only exact identities and the explicit 10/11-digit NANP variants used
// by BlueFerry. Never match arbitrary international-number suffixes.
func contactFor(contacts map[string]Contact, address string) (Contact, bool) {
	address = canonical(address)
	if c, ok := contacts[address]; ok {
		return c, true
	}
	digits := strings.TrimPrefix(address, "+")
	for _, v := range []string{digits, "+" + digits} {
		if c, ok := contacts[v]; ok {
			return c, true
		}
	}
	alternate := ""
	if len(digits) == 10 {
		alternate = "1" + digits
	} else if len(digits) == 11 && strings.HasPrefix(digits, "1") {
		alternate = digits[1:]
	}
	if alternate != "" {
		for _, v := range []string{alternate, "+" + alternate} {
			if c, ok := contacts[v]; ok {
				return c, true
			}
		}
	}
	return Contact{}, false
}
