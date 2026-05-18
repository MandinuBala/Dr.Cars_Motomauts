const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const User = require("./models/User");
const Vehicle = require("./models/vehicle");
const Appointment = require("./models/Appointment");
const ServiceReceipt = require("./models/ServiceReceipt");
const ServiceRecord = require("./models/ServiceRecord");
const ServiceCenterRequest = require("./models/ServiceCenterRequest");
const Feedback = require("./models/Feedback");
const VehicleDocument = require('./models/VehicleDocument');// insuerance and license documents
const multer = require('multer');
const path = require('path');

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());


const https = require('https');
// Deploy v2 - proxy route for 3D models

// Proxy route for 3D models from GitHub Releases
app.get('/models/:filename', (req, res) => {
  const filename = req.params.filename;
  const githubUrl = `https://github.com/MandinuBala/Dr.Cars-FYP/releases/download/models-v1/${filename}`;
  
  res.setHeader('Access-Control-Allow-Origin', '*');
  
  const fetchUrl = (url) => {
    https.get(url, { headers: { 'User-Agent': 'DrCars-FYP' } }, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        fetchUrl(response.headers.location);
        return;
      }
      res.setHeader('Content-Type', 'model/gltf-binary');
      response.pipe(res);
    }).on('error', () => {
      res.status(500).json({ error: 'Failed to fetch model' });
    });
  };
  
  fetchUrl(githubUrl);
});

// Serve document photos statically
app.use('/documents', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
}, express.static('public/documents'));

// Multer config for document photo uploads
const documentStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'public/documents/'),
  filename: (req, file, cb) => cb(null, `${Date.now()}_${file.originalname}`),
});
const documentUpload = multer({ storage: documentStorage });

// CONNECT TO MONGODBser
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Connected"))
  .catch(err => console.log("MongoDB connection error:", err));

app.get("/", (req, res) => {
  res.send("Dr.Cars Backend Running");
});

// ---------------------- SIGNUP ROUTE ----------------------
app.post("/user", async (req, res) => {
  try {
    const { name, email, username, password, userType, address, contact, createdAt } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email and password are required" });
    }

    const existingEmail = await User.findOne({ email });
    if (existingEmail) {
      return res.status(400).json({ message: "Email already in use" });
    }

    if (username) {
      const existingUsername = await User.findOne({ username });
      if (existingUsername) {
        return res.status(400).json({ message: "Username already in use" });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = await User.create({
      name,
      email,
      username,
      password: hashedPassword,
      userType: userType || "Vehicle Owner",
      address,
      contact,
      createdAt: createdAt || new Date(),
    });

    res.status(201).json({ message: "User created successfully", user: newUser });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- LOGIN ROUTE ----------------------
// Supports both email and username login
app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email/username and password are required" });
    }

    // Search by email OR username
    const user = await User.findOne({
      $or: [{ email }, { username: email }]
    });

    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    res.json({
      token,
      user: {
        id: user._id,
        _id: user._id,
        uid: user.uid || user._id,
        email: user.email,
        name: user.name,
        username: user.username,
        userType: user.userType,
      },
      userType: user.userType,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- REGISTER ROUTE ----------------------
app.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: "User already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    await User.create({
      name,
      email,
      password: hashedPassword,
    });

    res.status(201).json({ message: "User registered successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- GET USER BY EMAIL ----------------------
app.get("/user/email/:email", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- GET USER BY USERNAME ----------------------
app.get("/user/username/:username", async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ exists: false });
    res.json({ exists: true, ...user.toObject() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- UPDATE USER BY EMAIL ----------------------
app.put("/user/:email", async (req, res) => {
  try {
    const updated = await User.findOneAndUpdate(
      { email: req.params.email },
      req.body,
      { new: true }
    );
    if (!updated) return res.status(404).json({ message: "User not found" });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- RESET PASSWORD ----------------------
app.post("/reset-password", async (req, res) => {
  try {
    const { input } = req.body;
    const user = await User.findOne({
      $or: [{ email: input }, { username: input }]
    });
    if (!user) return res.status(404).json({ message: "User not found" });
    // In production, send a reset email here
    res.json({ message: "Password reset link sent" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- LOGOUT ----------------------
app.post("/logout", (req, res) => {
  res.status(200).json({ message: "Logged out" });
});

// ADD VEHICLE
app.post("/vehicles", async (req, res) => {
  try {
    const { userId, uid, brand, model, year, plateNumber, vehicleNumber, selectedBrand, selectedModel, vehicleType, mileage, vehiclePhotoUrl } = req.body;

    const newVehicle = await Vehicle.create({
      userId: userId || uid,
      brand,
      model,
      year,
      plateNumber,
      vehicleNumber: vehicleNumber || plateNumber,
      selectedBrand,
      selectedModel,
      vehicleType,
      mileage,
      vehiclePhotoUrl,
      uid: uid || userId,
    });

    res.status(201).json(newVehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY VEHICLE NUMBER
app.get("/vehicles/number/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const vehicle = await Vehicle.findOne({ vehicleNumber });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }
    res.json(vehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY USER IDENTIFIER
app.get("/vehicles/:uid", async (req, res) => {
  try {
    const { uid } = req.params;

    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }

    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id });
    }

    const vehicle = await Vehicle.findOne({ $or: vehicleFilter });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

    res.json({
      ...vehicle.toObject(),
      vehicleNumber: vehicle.vehicleNumber || vehicle.plateNumber || "",
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET USER BY ID OR UID
app.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE CENTER USERS BY CITY
app.get("/service-centers", async (req, res) => {
  try {
    const city = (req.query.city || "").toString().trim();
    const cityValues = city
      ? [city, city.toLowerCase(), city.toUpperCase()]
      : [];

    const roleFilter = {
      $or: [{ userType: "Service Center" }, { "User Type": "Service Center" }],
    };

    if (!city) {
      const users = await User.find(roleFilter);
      return res.json(users);
    }

    // Direct match on user city metadata (for newer accepted accounts).
    const directUsers = await User.find({
      ...roleFilter,
      $or: [
        { city: { $in: cityValues } },
        { branch: { $in: cityValues } },
      ],
    });

    // Backward-compatible match via accepted request city (older accounts).
    const acceptedRequests = await ServiceCenterRequest.find({
      status: "accepted",
      city: { $in: cityValues },
    }).select("email username");

    const emails = acceptedRequests
      .map((r) => (r.email || "").toString())
      .filter((v) => v);
    const usernames = acceptedRequests
      .map((r) => (r.username || "").toString())
      .filter((v) => v);

    let requestMatchedUsers = [];
    if (emails.length || usernames.length) {
      requestMatchedUsers = await User.find({
        ...roleFilter,
        $or: [
          ...(emails.length ? [{ email: { $in: emails } }] : []),
          ...(usernames.length ? [{ username: { $in: usernames } }] : []),
        ],
      });
    }

    const merged = [...directUsers, ...requestMatchedUsers];
    const seen = new Set();
    const users = merged.filter((u) => {
      const id = u._id.toString();
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    });

    return res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE USER (by id)
app.post("/users", async (req, res) => {
  try {
    const payload = { ...req.body };
    const created = await User.create(payload);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// UPDATE USER BY ID/UID
app.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const updated = await User.findOneAndUpdate({ $or: filters }, req.body, {
      new: true,
    });

    if (!updated) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE USER BY ID/UID
app.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const deleted = await User.findOneAndDelete({ $or: filters });
    if (!deleted) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ message: "User deleted" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// UPDATE VEHICLE BY USER IDENTIFIER
app.put("/vehicles/by-user/:uid", async (req, res) => {
  try {
    const { uid } = req.params;
    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }
    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }, { uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id.toString() });
      vehicleFilter.push({ userId: user._id });
    }

    const updated = await Vehicle.findOneAndUpdate(
      { $or: vehicleFilter },
      { ...req.body, uid, userId: uid },
      { new: true, upsert: true }
    );

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET APPOINTMENTS BY VEHICLE NUMBER
app.get("/appointments/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const appointments = await Appointment.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET APPOINTMENTS BY SERVICE CENTER (OPTIONAL STATUS FILTER)
app.get("/appointments/service-center/:serviceCenterUid", async (req, res) => {
  try {
    const { serviceCenterUid } = req.params;
    const { status } = req.query;

    const filter = { serviceCenterUid };
    if (status) {
      filter.status = status;
    }

    const appointments = await Appointment.find(filter).sort({ createdAt: 1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE APPOINTMENT
app.post("/appointments", async (req, res) => {
  try {
    const created = await Appointment.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// APPOINTMENT COUNT FOR DATE RANGE
app.get("/appointments/count", async (req, res) => {
  try {
    const { start, end, serviceCenterUid } = req.query;
    const query = {};

    if (serviceCenterUid) {
      query.serviceCenterUid = serviceCenterUid;
    }

    if (start && end) {
      query.date = { $gte: start, $lt: end };
    }

    const count = await Appointment.countDocuments(query);
    res.json({ count });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// UPDATE APPOINTMENT STATUS
app.patch("/appointments/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!["pending", "accepted", "rejected"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const updated = await Appointment.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE APPOINTMENT
app.delete("/appointments/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Appointment.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json({ message: "Appointment deleted" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE SERVICE RECEIPT
app.post("/service-receipts", async (req, res) => {
  try {
    const created = await ServiceReceipt.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY VEHICLE
app.get("/service-receipts/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const receipts = await ServiceReceipt.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(receipts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY SERVICE CENTER
app.get("/service-receipts/service-center/:serviceCenterId", async (req, res) => {
  try {
    const { serviceCenterId } = req.params;
    const { status, vehicleNumber } = req.query;

    const query = { serviceCenterId };
    if (status) query.status = status;
    if (vehicleNumber) query.vehicleNumber = vehicleNumber;

    const receipts = await ServiceReceipt.find(query).sort({ createdAt: -1 });
    res.json(receipts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// UPDATE SERVICE RECEIPT STATUS
app.patch("/service-receipts/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const updated = await ServiceReceipt.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Receipt not found" });
    }

    if (status === "finished") {
      const vehicle = await Vehicle.findOne({
        vehicleNumber: updated.vehicleNumber,
      });

      console.log("Vehicle found:", vehicle);
      console.log("Vehicle userId:", vehicle?.userId);
      console.log("Vehicle uid:", vehicle?.uid);

      const userId = vehicle?.userId?.toString() || vehicle?.uid?.toString();
      console.log("userId being saved to ServiceRecord:", userId);

      if (userId) {
        const serviceCenterName =
          updated["Service Center Name"] || "Unknown Service Center";

        const services = updated.services
          ? Object.fromEntries(updated.services)
          : {};

        console.log("Services to create records for:", services);

        for (const [serviceName, price] of Object.entries(services)) {
          const record = await ServiceRecord.create({
            userId,
            currentMileage: updated.currentMileage,
            serviceMileage: updated.currentMileage,
            serviceProvider: serviceCenterName,
            serviceCost: price?.toString() || "0",
            serviceType: serviceName,
            date: updated.createdAt || new Date(),
          });
          console.log("Created ServiceRecord:", record);
        }
      } else {
        console.log("No userId found — vehicle may not be linked to a user");
      }
    }

    res.json(updated);
  } catch (error) {
    console.error("Error in PATCH /service-receipts/:id/status:", error);
    res.status(500).json({ error: error.message });
  }
});

app.get("/service-records/user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    // Build all possible userId formats to match against
    const filters = [{ userId }];

    // Look up the user to get all their ID variants
    const userFilters = [{ uid: userId }];
    if (mongoose.Types.ObjectId.isValid(userId)) {
      userFilters.push({ _id: userId });
    }
    const user = await User.findOne({ $or: userFilters });
    if (user) {
      filters.push({ userId: user._id.toString() });
      if (user.uid) filters.push({ userId: user.uid.toString() });
    }

    const records = await ServiceRecord.find({ $or: filters }).sort({ createdAt: -1 });
    console.log(`Records found for ${userId}:`, records.length);
    res.json(records);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


// DELETE SERVICE RECEIPT
app.delete("/service-receipts/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceReceipt.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ message: "Receipt not found" });
    }
    res.json({ message: "Receipt deleted" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE SERVICE RECORD
app.post("/service-records", async (req, res) => {
  try {
    const created = await ServiceRecord.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECORDS BY USER
app.get("/service-records/user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    // Build all possible userId formats to match against
    const filters = [{ userId }];

    // Look up the user to get all their ID variants
    const userFilters = [{ uid: userId }];
    if (mongoose.Types.ObjectId.isValid(userId)) {
      userFilters.push({ _id: userId });
    }
    const user = await User.findOne({ $or: userFilters });
    if (user) {
      filters.push({ userId: user._id.toString() });
      if (user.uid) filters.push({ userId: user.uid.toString() });
    }

    const records = await ServiceRecord.find({ $or: filters }).sort({ createdAt: -1 });
    console.log(`Records found for ${userId}:`, records.length);
    res.json(records);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


// FEEDBACK LISTING
app.get("/feedbacks", async (req, res) => {
  try {
    const { serviceCenterId } = req.query;
    const query = serviceCenterId ? { serviceCenterId } : {};
    const feedbacks = await Feedback.find(query).sort({ createdAt: -1 });
    res.json(feedbacks);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// LEGACY SERVICE CENTER DUPLICATE CHECK (used by mobile signup screen)
app.get("/api/service/check", async (req, res) => {
  try {
    const field = (req.query.field || "").toString();
    const value = (req.query.value || "").toString().trim();

    if (!field || !value) {
      return res.status(400).json({ message: "field and value are required", exists: false });
    }

    const normalizedField = field.toLowerCase();
    let exists = false;

    if (normalizedField === "email") {
      const user = await User.findOne({
        $or: [{ email: value }, { Email: value }],
      });
      const request = await ServiceCenterRequest.findOne({ email: value });
      exists = !!user || !!request;
    } else if (normalizedField === "username") {
      const user = await User.findOne({
        $or: [{ username: value }, { Username: value }],
      });
      const request = await ServiceCenterRequest.findOne({ username: value });
      exists = !!user || !!request;
    } else if (normalizedField === "servicecentername") {
      const safeValue = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const exactCI = new RegExp(`^${safeValue}$`, "i");

      const request = await ServiceCenterRequest.findOne({ serviceCenterName: exactCI });
      const user = await User.findOne({
        $or: [{ serviceCenterName: exactCI }, { name: exactCI }, { Name: exactCI }],
      });
      exists = !!user || !!request;
    } else {
      return res.status(400).json({ message: "unsupported field", exists: false });
    }

    return res.json({ exists });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// LEGACY SERVICE CENTER REQUEST CREATE (used by mobile signup screen)
app.post("/api/service/request", async (req, res) => {
  try {
    const plainPassword = (req.body.password || "").toString();
    if (!plainPassword || plainPassword.length < 6) {
      return res.status(400).json({ message: "password must be at least 6 characters" });
    }

    const passwordHash = await bcrypt.hash(plainPassword, 10);

    const payload = {
      serviceCenterName: req.body.serviceCenterName,
      email: req.body.email,
      passwordHash,
      ownerName: req.body.ownerName,
      nic: req.body.nic,
      regNumber: req.body.regNumber,
      address: req.body.address,
      contact: req.body.contact,
      notes: req.body.notes,
      username: req.body.username,
      city: req.body.city,
      status: "pending",
    };

    if (!payload.email || !payload.serviceCenterName || !payload.username) {
      return res.status(400).json({ message: "email, username and serviceCenterName are required" });
    }

    const [existingUserByEmail, existingReqByEmail] = await Promise.all([
      User.findOne({ $or: [{ email: payload.email }, { Email: payload.email }] }),
      ServiceCenterRequest.findOne({ email: payload.email }),
    ]);

    if (existingUserByEmail || existingReqByEmail) {
      return res.status(409).json({ message: "Email already in use" });
    }

    const [existingUserByUsername, existingReqByUsername] = await Promise.all([
      User.findOne({ $or: [{ username: payload.username }, { Username: payload.username }] }),
      ServiceCenterRequest.findOne({ username: payload.username }),
    ]);

    if (existingUserByUsername || existingReqByUsername) {
      return res.status(409).json({ message: "Username already in use" });
    }

    const created = await ServiceCenterRequest.create(payload);
    return res.status(200).json({
      message: "Request submitted",
      requestId: created._id,
      status: created.status,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// LIST SERVICE CENTER REQUESTS (ADMIN)
app.get("/service-center-requests", async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};

    if (status) {
      query.status = status;
    }

    const requests = await ServiceCenterRequest.find(query)
      .select("-passwordHash")
      .sort({ createdAt: -1 });
    return res.json(requests);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ACCEPT SERVICE CENTER REQUEST (ADMIN)
app.post("/service-center-requests/accept/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const request = await ServiceCenterRequest.findById(id).select(
      "+passwordHash"
    );

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    const fallbackPasswordHash = await bcrypt.hash(
      `${request.username}@123`,
      10
    );
    const loginPasswordHash = request.passwordHash || fallbackPasswordHash;

    // Ensure a Service Center user exists for approved requests.
    let serviceCenterUser = await User.findOne({
      $or: [{ email: request.email }, { username: request.username }],
    });

    if (!serviceCenterUser) {
      serviceCenterUser = await User.create({
        name: request.serviceCenterName || request.ownerName || "Service Center",
        serviceCenterName: request.serviceCenterName,
        email: request.email,
        username: request.username,
        password: loginPasswordHash,
        address: request.address,
        contact: request.contact,
        city: request.city,
        branch: request.city,
        userType: "Service Center",
      });
    } else {
      serviceCenterUser.userType = "Service Center";
      serviceCenterUser.serviceCenterName =
        request.serviceCenterName || serviceCenterUser.serviceCenterName;
      serviceCenterUser.city = request.city || serviceCenterUser.city;
      serviceCenterUser.branch = request.city || serviceCenterUser.branch;
      await serviceCenterUser.save();
    }

    request.status = "accepted";
    await request.save();

    return res.json({
      message: "Request accepted",
      userId: serviceCenterUser._id,
      username: request.username,
      status: request.status,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// REJECT SERVICE CENTER REQUEST (ADMIN)
app.put("/service-center-requests/reject/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "rejected" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request rejected", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// RESTORE REJECTED REQUEST TO PENDING (ADMIN)
app.put("/service-center-requests/restore/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "pending" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request restored", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// DELETE SERVICE CENTER REQUEST (ADMIN)
app.delete("/service-center-requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceCenterRequest.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request deleted" });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// SERVICE CENTER REQUEST STATUS CHECK BY EMAIL
app.get("/service-center-status/:email", async (req, res) => {
  try {
    const { email } = req.params;

    const approvedUser = await User.findOne({
      $and: [
        { $or: [{ Email: email }, { email }] },
        { $or: [{ "User Type": "Service Center" }, { userType: "Service Center" }] },
      ],
    });

    if (approvedUser) {
      return res.json({
        status: "approved",
        username: approvedUser.username || "",
      });
    }

    const request = await ServiceCenterRequest.findOne({ email });
    if (!request) {
      return res.json({ status: "not-found" });
    }

    res.json({ status: request.status, username: request.username || "" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- GOOGLE AUTH ----------------------
app.post("/auth/google", async (req, res) => {
  try {
    const { googleId, email, name, photoUrl } = req.body;

    if (!googleId || !email) {
      return res.status(400).json({ message: "googleId and email are required" });
    }

    let user = await User.findOne({ $or: [{ googleId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        googleId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.googleId) {
      user.googleId = googleId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    res.json({
      token,
      isNewUser,
      user: {
        _id: user._id,
        uid: user.uid || user._id,
        email: user.email,
        name: user.name,
        userType: user.userType || "Vehicle Owner",
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- FACEBOOK AUTH ----------------------
app.post("/auth/facebook", async (req, res) => {
  try {
    const { facebookId, email, name, photoUrl } = req.body;

    if (!facebookId || !email) {
      return res.status(400).json({ message: "facebookId and email are required" });
    }

    let user = await User.findOne({ $or: [{ facebookId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        facebookId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.facebookId) {
      user.facebookId = facebookId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    res.json({
      token,
      isNewUser,
      user: {
        _id: user._id,
        uid: user.uid || user._id,
        email: user.email,
        name: user.name,
        userType: user.userType || "Vehicle Owner",
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CHANGE PASSWORD BY USER ID
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
// ---------------------- VEHICLE DOCUMENTS ----------------------

// Upload document photo
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const url = `${process.env.BASE_URL || 'http://localhost:5000'}/documents/${req.file.filename}`;
  res.json({ url });
});

// Add new document record
app.post('/vehicle-documents', async (req, res) => {
  try {
    const doc = await VehicleDocument.create({
      userId:         req.body.userId,
      type:           req.body.type,
      label:          req.body.label,
      documentNumber: req.body.documentNumber,
      vehiclePlate:   req.body.vehiclePlate,
      issueDate:      req.body.issueDate ? new Date(req.body.issueDate) : null,
      expiryDate:     new Date(req.body.expiryDate),
      photoUrl:       req.body.photoUrl || '',
    });
    res.status(201).json(doc);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get all documents for a user
app.get('/vehicle-documents/:userId', async (req, res) => {
  try {
    const docs = await VehicleDocument.find({ userId: req.params.userId })
      .sort({ expiryDate: 1 });
    res.json(docs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete a document
app.delete('/vehicle-documents/:id', async (req, res) => {
  try {
    const { ObjectId } = require('mongoose').Types;
    await VehicleDocument.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(process.env.PORT || 5000, () => {
  console.log("Server running on port 5000");
});