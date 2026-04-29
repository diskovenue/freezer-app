//
//  AppError.swift
//  freezer-app
//
//  Created by OpenAI on 18.08.25.
//

import Foundation

enum AppError {
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        let rawMessage = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = rawMessage.lowercased()

        if rawMessage.isEmpty {
            return "Es ist ein unbekannter Fehler aufgetreten."
        }

        if normalized.contains("invalid login credentials") {
            return "Die E-Mail oder das Passwort ist nicht korrekt."
        }

        if normalized.contains("email not confirmed") {
            return "Die E-Mail-Adresse wurde noch nicht bestätigt."
        }

        if normalized.contains("refresh token") || normalized.contains("jwt") || normalized.contains("session") {
            return "Deine Anmeldung konnte nicht geprüft werden. Bitte melde dich erneut an."
        }

        if normalized.contains("network")
            || normalized.contains("internet connection")
            || normalized.contains("offline")
            || normalized.contains("timed out")
            || normalized.contains("timeout") {
            return "Netzwerkfehler. Bitte prüfe deine Verbindung und versuche es erneut."
        }

        if normalized.contains("duplicate key") || normalized.contains("already exists") {
            return "Die Daten konnten nicht gespeichert werden, weil bereits ein gleicher Eintrag existiert."
        }

        if normalized.contains("permission denied")
            || normalized.contains("not allowed")
            || normalized.contains("unauthorized")
            || normalized.contains("forbidden") {
            return "Dafür fehlt die Berechtigung."
        }

        if normalized.contains("not found") {
            return "Der angeforderte Eintrag wurde nicht gefunden."
        }

        if normalized.contains("failed to fetch") || normalized.contains("could not")
            || normalized.contains("request failed") {
            return "Die Daten konnten nicht geladen werden. Bitte versuche es erneut."
        }

        return rawMessage
    }
}
