#!/usr/bin/env bash

###############################################################################
# Validation Library
###############################################################################

require_namespace() {

    namespace_exists "$1" || {

        log_error "Namespace '$1' not found."

        exit 1

    }

}

require_gatekeeper() {

    crd_exists constrainttemplates.templates.gatekeeper.sh || {

        log_error "Gatekeeper is not installed."

        exit 1

    }

}

require_kyverno() {

    crd_exists clusterpolicies.kyverno.io || {

        log_error "Kyverno CRDs not installed."

        exit 1

    }

}

require_json() {

    [ -f "$1" ] || {

        log_error "Missing file: $1"

        exit 1

    }

}