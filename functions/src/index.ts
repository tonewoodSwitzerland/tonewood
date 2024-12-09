import {onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import {defineSecret} from "firebase-functions/params";

admin.initializeApp();

const gmailEmail = defineSecret("GMAIL_EMAIL");
const gmailPassword = defineSecret("GMAIL_PASSWORD");

interface EmailError {
  code?: string;
  message?: string;
  stack?: string;
}


export const sendEmail = onCall({
  region: "europe-west1",
  enforceAppCheck: false,
  invoker: "public",
  secrets: [gmailEmail, gmailPassword],
}, async (request) => {
  console.log("SendEmail function called");
  console.log("Request data:", JSON.stringify(request.data, null, 2));
  console.log("Secrets loaded...");
  console.log("GMAIL_EMAIL:", !!gmailEmail.value());
  console.log("GMAIL_PASSWORD:", !!gmailPassword.value());
  try {
    console.log("Creating transporter...");
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: gmailEmail.value(),
        pass: gmailPassword.value(),
      },
      debug: true, // Enable debug output
      logger: true, // Log to console
    });

    console.log("Verifying transporter...");
    await transporter.verify();
    console.log("Transporter verified successfully");

    const {to, subject, html, attachments = []} = request.data;

    console.log("Preparing mail options...");
    console.log("To:", to);
    console.log("Subject:", subject);
    console.log("Number of attachments:", attachments.length);

    const mailOptions = {
      from: `"Tonewood Switzerland" <${gmailEmail.value()}>`,
      to,
      subject,
      html,
      attachments,
    };

    console.log("Sending email...");
    const info = await transporter.sendMail(mailOptions);
    console.log("Email sent successfully");
    console.log("Message ID:", info.messageId);
    console.log("Response:", info.response);

    return {
      success: true,
      messageId: info.messageId,
      response: info.response,
    };
  } catch (err) {
    const error = err as EmailError;
    console.error("Error in sendEmail:", error);
    console.error("Error stack:", error.stack || "No stack trace available");
    console.error("Error details:", JSON.stringify(error, null, 2));

    // Prüfe spezifische Fehlerbedingungen
    if (error.code === "EAUTH") {
      console.error("Authentication failed. Check Gmail credentials.");
    }

    throw new Error(error.message || "Failed to send email");
  }
});

