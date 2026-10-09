import Foundation

/// Public pages hosted with GitHub Pages from the repository's docs/ folder.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://ntm52.github.io/Helichopter/privacy.html")!
    static let support = URL(string: "https://ntm52.github.io/Helichopter/support.html")!
    static let supportEmail = "helichopter.support@gmail.com"

    static let privacySummary = """
        Helichopter does not collect, share, or sell any personal information. There are no accounts, ads, analytics, or tracking, and the app never connects to the internet.

        Your settings, scores, and guide progress are stored only on this device. Deleting the app removes them.

        Questions: \(supportEmail)
        """

    static let acknowledgements = """
        Music: "Simple Majestic Choir Melody" by Louswan, edited by SouljaUnit. Freesound, Creative Commons 0.

        Artwork and sound effects by Nathan Mayo.

        Based on original code by Astemir Eleev:

        Copyright (c) 2018, Astemir Eleev. All rights reserved.

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

        * Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
        """
}
