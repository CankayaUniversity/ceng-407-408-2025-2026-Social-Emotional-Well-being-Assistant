const prisma = require("../src/prisma");

async function findUserByEmail(email) {
  return prisma.user.findUnique({ where: { email } });
}

async function createUser({ email, passwordHash, name }) {
  // id'yi asla yazma!
  return prisma.user.create({
    data: {
      email,
      passwordHash,
      name: name || null
    },
    select: {
      id: true,
      email: true,
      name: true
    }
  });
}

async function findUserById(id) {
  return prisma.user.findUnique({
    where: { id },
    select: { id: true, email: true, name: true }
  });
}

module.exports = { findUserByEmail, createUser, findUserById };
